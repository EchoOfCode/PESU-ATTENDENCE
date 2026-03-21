import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';
import '../models/timetable.dart';

/// Handles all persistence: secure credential storage, attendance data caching,
/// timetable/calendar storage, and pushing data to the native homescreen widget.
class StorageService {
  static const _attendanceKey = 'attendance_data';
  static const _usernameKey = 'pesu_username';
  static const _passwordKey = 'pesu_password';
  static const _timetableKey = 'timetable_data';
  static const _academicDatesKey = 'academic_dates';

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // -- Credentials (Android Keystore-backed) --

  static Future<void> saveCredentials(String username, String password) async {
    await _secureStorage.write(key: _usernameKey, value: username);
    await _secureStorage.write(key: _passwordKey, value: password);
  }

  static Future<({String? username, String? password})> getCredentials() async {
    final username = await _secureStorage.read(key: _usernameKey);
    final password = await _secureStorage.read(key: _passwordKey);
    return (username: username, password: password);
  }

  static Future<bool> hasCredentials() async {
    final creds = await getCredentials();
    return creds.username != null &&
        creds.username!.isNotEmpty &&
        creds.password != null &&
        creds.password!.isNotEmpty;
  }

  static Future<void> clearCredentials() async {
    await _secureStorage.delete(key: _usernameKey);
    await _secureStorage.delete(key: _passwordKey);
  }

  // -- Attendance cache (SharedPreferences) --

  static Future<void> saveAttendanceData(AttendanceData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_attendanceKey, data.toJsonString());
  }

  static Future<AttendanceData?> getAttendanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_attendanceKey);
    if (jsonString == null) return null;
    try {
      return AttendanceData.fromJsonString(jsonString);
    } catch (_) {
      return null;
    }
  }

  // -- Timetable --

  static Future<void> saveTimetable(Timetable tt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_timetableKey, tt.toJsonString());
  }

  static Future<Timetable?> getTimetable() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_timetableKey);
    if (s == null) return null;
    try {
      return Timetable.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  // -- Academic dates --

  static Future<void> saveAcademicDates(AcademicDates dates) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_academicDatesKey, dates.toJsonString());
  }

  static Future<AcademicDates?> getAcademicDates() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_academicDatesKey);
    if (s == null) return null;
    try {
      return AcademicDates.fromJsonString(s);
    } catch (_) {
      return null;
    }
  }

  // -- Widget data sync --

  /// Pushes attendance + timetable + calendar + quote data to the widget.
  static Future<void> syncToWidget(AttendanceData data) async {
    final overallStr = data.overallPercentage != null
        ? '${data.overallPercentage!.toStringAsFixed(1)}%'
        : 'N/A';

    String colorLevel;
    if (data.overallPercentage == null) {
      colorLevel = 'unknown';
    } else if (data.overallPercentage! >= 85) {
      colorLevel = 'good';
    } else if (data.overallPercentage! >= 75) {
      colorLevel = 'warning';
    } else {
      colorLevel = 'danger';
    }

    final lastUpdated = _formatLastUpdated(data.lastUpdated);

    final subjectsJsonList = data.subjects.map((s) => {
          'title': s.title,
          'percentage': s.percentage != null
              ? '${s.percentage!.toStringAsFixed(2)}%'
              : 'N/A',
          'level': s.level.name,
        }).toList();

    // Timetable: compute next class
    final timetable = await getTimetable();
    String nextClassName = '';
    String nextClassTime = '';
    String breakMessage = '';

    if (timetable != null) {
      final next = timetable.nextClass();
      if (next != null) {
        nextClassName = next.subjectTitle;
        nextClassTime = next.startTime;
      } else {
        breakMessage = _pickBreakMessage();
      }
    }

    // Academic dates: compute next event
    final acDates = await getAcademicDates();
    String academicDateLabel = '';
    String academicDateValue = '';
    if (acDates != null) {
      final next = acDates.nextEvent;
      if (next != null) {
        academicDateLabel = next.label;
        academicDateValue = DateFormat('d MMM').format(next.date);
      }

      // Also format LWD if set
      if (acDates.lwd != null && acDates.lwd!.isAfter(DateTime.now())) {
        if (academicDateLabel.isNotEmpty) {
          academicDateLabel += '  ·  LWD';
          academicDateValue += '  ·  ${DateFormat('d MMM').format(acDates.lwd!)}';
        } else {
          academicDateLabel = 'LWD';
          academicDateValue = DateFormat('d MMM').format(acDates.lwd!);
        }
      }
    }

    // Date string for header
    final dateStr = DateFormat('EEE, d MMM').format(DateTime.now());

    // Random funny quote
    final quote = _funnyQuotes[Random().nextInt(_funnyQuotes.length)];

    final widgetDataJson = jsonEncode({
      'overall': overallStr,
      'colorLevel': colorLevel,
      'lastUpdated': lastUpdated,
      'subjects': subjectsJsonList,
      'dateStr': dateStr,
      'nextClassName': nextClassName,
      'nextClassTime': nextClassTime,
      'breakMessage': breakMessage,
      'academicDateLabel': academicDateLabel,
      'academicDateValue': academicDateValue,
      'funnyQuote': quote,
    });

    await HomeWidget.saveWidgetData<String>('widgetDataJson', widgetDataJson);
    await HomeWidget.updateWidget(androidName: 'AttendanceWidgetProvider');
  }

  static String _formatLastUpdated(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  static String _pickBreakMessage() {
    final messages = [
      'No more classes today ✨',
      'Freedom! Go touch grass 🌿',
      'Rest time, you earned it 😌',
      'Class-free zone activated 🎮',
      'Netflix time? We won\'t judge 📺',
    ];
    return messages[Random().nextInt(messages.length)];
  }

  static const _funnyQuotes = [
    '"Sleep is just offline studying"',
    '"My bed has better attendance than me"',
    '"404: Motivation not found"',
    '"I came, I saw, I bunked"',
    '"Attendance is temporary, GPA is eternal... wait"',
    '"Every class skipped is a class earned... right?"',
    '"Proxy mark karo yaar"',
    '"Will study tomorrow — said me, yesterday"',
    '"Going to class is just speedrunning boredom"',
    '"Born to bunk, forced to attend"',
    '"Insert attendance here ▶"',
    '"If attendance was optional, I\'d be at 200%... in sleeping"',
    '"Schrödinger\'s student: both in class and not"',
    '"The mitochondria is the powerhouse of the cell. Still."',
    '"I don\'t skip class, I give others extra space"',
    '"My WiFi has better uptime than my attendance"',
    '"Some call it bunking, I call it self-care"',
    '"75% is not the goal, it\'s the lifestyle"',
    '"Teacher: Aaj kaun absent hai? Me: *exists in quantum state*"',
    '"GPA is just a number. So is 0."',
  ];
}
