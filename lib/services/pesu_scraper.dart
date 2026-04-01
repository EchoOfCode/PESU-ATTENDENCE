import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/attendance.dart';
import '../models/timetable.dart';

/// Scrapes PESU Academy for attendance data.
///
/// Replicates the login + attendance fetch flow used by the
/// pesu-dev/pesuacademy Python library, ported to Dart with
/// manual cookie management and retry logic.
class PesuScraper {
  static const String _baseUrl = 'https://www.pesuacademy.com/Academy';
  static const int _maxRetries = 3;

  final Map<String, String> _cookies = {};

  /// Full pipeline: login → resolve latest semester → scrape attendance table.
  Future<AttendanceData> fetchAttendance({
    required String username,
    required String password,
  }) async {
    await _login(username, password);

    final semesterIds = await _fetchSemesterIds();
    if (semesterIds.isEmpty) {
      throw PesuScraperException('No semesters found for this account.');
    }

    // Always pick the numerically highest semester (most recent).
    final latestKey = semesterIds.keys.reduce((a, b) => a > b ? a : b);
    final subjects = await _fetchAttendanceForSemester(semesterIds[latestKey]!);
    final overall = AttendanceData.computeOverall(subjects);

    return AttendanceData(
      subjects: subjects,
      overallPercentage: overall,
      lastUpdated: DateTime.now(),
    );
  }

  // -- Authentication --

  Future<void> _login(String username, String password) async {
    // Grab the CSRF token from the login page.
    final loginPage = await _get('/');
    final doc = html_parser.parse(loginPage.body);
    final csrfMeta = doc.querySelector('meta[name="csrf-token"]');

    if (csrfMeta == null) {
      throw PesuScraperException(
          'Could not find CSRF token. PESU Academy may be down.');
    }

    final response = await _post('/j_spring_security_check', body: {
      '_csrf': csrfMeta.attributes['content']!,
      'j_username': username,
      'j_password': password,
    });

    if (response.body.contains('Invalid credentials') ||
        response.body.contains('Login to PESU Academy')) {
      throw PesuScraperException(
          'Authentication failed. Check your SRN and password.');
    }
  }

  // -- Semester discovery --

  Future<Map<int, String>> _fetchSemesterIds() async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await _get(
      '/a/studentProfilePESU/getStudentSemestersPESU',
      queryParams: {'_': ts},
    );

    final doc = html_parser.parse(response.body);
    final Map<int, String> ids = {};
    final numRe = RegExp(r'\d+');

    for (final option in doc.querySelectorAll('option')) {
      final rawValue = option.attributes['value'];
      final textMatch = numRe.firstMatch(option.text.trim());
      if (rawValue == null || textMatch == null) continue;

      // The value attribute sometimes has escaped quotes, so we grab digits only.
      final cleanValue =
          numRe.allMatches(rawValue).map((m) => m.group(0)).join();
      if (cleanValue.isEmpty) continue;

      ids[int.parse(textMatch.group(0)!)] = cleanValue;
    }

    return ids;
  }

  // -- Attendance table parsing --

  Future<List<SubjectAttendance>> _fetchAttendanceForSemester(
      String semesterId) async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await _get('/s/studentProfilePESUAdmin', queryParams: {
      'menuId': '660',
      'controllerMode': '6407',
      'actionType': '8',
      'batchClassId': semesterId,
      '_': ts,
    });

    final doc = html_parser.parse(response.body);
    final table = doc.querySelector('table.box-shadow');
    if (table == null || table.text.contains('Data Not Available')) return [];

    final tbody = table.querySelector('tbody');
    if (tbody == null) return [];

    final List<SubjectAttendance> result = [];
    for (final row in tbody.querySelectorAll('tr')) {
      final cols = row.querySelectorAll('td').map((c) => c.text.trim()).toList();
      if (cols.length < 4) continue;

      int? attended;
      int? total;
      if (cols[2].contains('/')) {
        final parts = cols[2].split('/');
        if (parts.length == 2) {
          attended = int.tryParse(parts[0].trim());
          total = int.tryParse(parts[1].trim());
        }
      }

      result.add(SubjectAttendance(
        code: cols[0],
        title: cols[1],
        attended: attended,
        total: total,
        percentage: double.tryParse(cols[3]),
      ));
    }

    return result;
  }

  // -- Timetable scraping --

  Future<Timetable> scrapeTimetable() async {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final response = await _get('/s/studentProfilePESUAdmin', queryParams: {
      'menuId': '669',
      'controllerMode': '6415',
      'actionType': '5',
      '_': ts,
    });

    final html = response.body;

    final templateRegex = RegExp(r'var timeTableTemplateDetailsJson=(.*?);', dotAll: true);
    final scheduleRegex = RegExp(r'var timeTableJson=(.*?);', dotAll: true);

    final templateMatch = templateRegex.firstMatch(html);
    final scheduleMatch = scheduleRegex.firstMatch(html);

    if (templateMatch == null || scheduleMatch == null) {
      throw PesuScraperException('Could not parse timetable data. Layout may have changed.');
    }

    final slotsJson = jsonDecode(templateMatch.group(1)!) as List<dynamic>;
    final scheduleJson = jsonDecode(scheduleMatch.group(1)!) as Map<String, dynamic>;

    String formatTime(dynamic rawTime) {
      if (rawTime is int) {
        final h = (rawTime ~/ 60).toString().padLeft(2, '0');
        final m = (rawTime % 60).toString().padLeft(2, '0');
        return '$h:$m';
      } else {
        final s = rawTime.toString();
        final parts = s.split(':');
        if (parts.length >= 2) {
          return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
        }
        return s;
      }
    }

    final Map<int, Map<String, String>> slotTimes = {};
    for (var s in slotsJson) {
      final map = s as Map<String, dynamic>;
      final orderedBy = map['orderedBy'] as int;
      slotTimes[orderedBy] = {
        'start': formatTime(map['startTime']),
        'end': formatTime(map['endTime']),
      };
    }

    final List<ClassSlot> results = [];

    for (final entry in scheduleJson.entries) {
      final key = entry.key;
      final valueList = entry.value as List<dynamic>;

      if (!key.startsWith('ttDivText_') || valueList.isEmpty) continue;

      final parts = key.split('_');
      if (parts.length < 3) continue;

      final dayIndex = int.tryParse(parts[1]); // 1=Mon .. 6=Sat
      final slotIndex = int.tryParse(parts[2]);

      if (dayIndex == null || slotIndex == null || dayIndex > 7) continue;

      final timeInfo = slotTimes[slotIndex];
      if (timeInfo == null) continue;

      var subjectRaw = valueList.first.toString();
      if (subjectRaw.startsWith('ttSubject&&')) {
        subjectRaw = subjectRaw.replaceFirst('ttSubject&&', '');
      }

      final subjParts = subjectRaw.split('-');
      String cleanTitle = subjectRaw;
      if (subjParts.length > 1) {
        cleanTitle = subjParts.sublist(1).join('-').trim();
      }

      results.add(ClassSlot(
        dayOfWeek: dayIndex,
        startTime: timeInfo['start']!,
        endTime: timeInfo['end']!,
        subjectTitle: cleanTitle.isEmpty ? subjectRaw : cleanTitle,
      ));
    }

    return Timetable(slots: results);
  }

  // -- HTTP helpers with cookie management and retries --

  Future<http.Response> _get(String path,
      {Map<String, String>? queryParams}) async {
    return _withRetries(() async {
      final uri =
          Uri.parse('$_baseUrl$path').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers());
      _updateCookies(response);

      // PESU Academy sometimes returns a 302 instead of following the redirect,
      // so we handle that manually.
      if (response.statusCode == 302 || response.statusCode == 301) {
        final loc = response.headers['location'];
        if (loc != null) {
          final redirectUri =
              Uri.parse(loc).isAbsolute ? Uri.parse(loc) : Uri.parse('$_baseUrl$loc');
          final r = await http.get(redirectUri, headers: _headers());
          _updateCookies(r);
          return r;
        }
      }
      return response;
    });
  }

  Future<http.Response> _post(String path,
      {Map<String, String>? body}) async {
    return _withRetries(() async {
      final uri = Uri.parse('$_baseUrl$path');
      final response = await http.post(uri, headers: {
        ..._headers(),
        'Content-Type': 'application/x-www-form-urlencoded',
      }, body: body);
      _updateCookies(response);

      if (response.statusCode == 302 || response.statusCode == 301) {
        final loc = response.headers['location'];
        if (loc != null) {
          final redirectUri =
              Uri.parse(loc).isAbsolute ? Uri.parse(loc) : Uri.parse('$_baseUrl$loc');
          final r = await http.get(redirectUri, headers: _headers());
          _updateCookies(r);
          return r;
        }
      }
      return response;
    });
  }

  Map<String, String> _headers() {
    final h = <String, String>{
      'User-Agent':
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    };
    if (_cookies.isNotEmpty) {
      h['Cookie'] = _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
    }
    return h;
  }

  void _updateCookies(http.Response response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;

    for (final chunk in raw.split(RegExp(r',(?=[^ ]+=)'))) {
      final parts = chunk.split(';');
      if (parts.isEmpty) continue;
      final kv = parts[0].trim().split('=');
      if (kv.length >= 2) _cookies[kv[0]] = kv.sublist(1).join('=');
    }
  }

  Future<http.Response> _withRetries(
      Future<http.Response> Function() request) async {
    Exception? last;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        return await request().timeout(const Duration(seconds: 30));
      } on Exception catch (e) {
        last = e;
        if (i < _maxRetries - 1) {
          await Future.delayed(Duration(seconds: 1 << i));
        }
      }
    }
    throw PesuScraperException('Request failed after $_maxRetries attempts: $last');
  }
}

class PesuScraperException implements Exception {
  final String message;
  PesuScraperException(this.message);

  @override
  String toString() => 'PesuScraperException: $message';
}
