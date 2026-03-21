import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/attendance.dart';

/// Handles all persistence: secure credential storage, attendance data caching,
/// and pushing data to the native Android homescreen widget.
class StorageService {
  static const _attendanceKey = 'attendance_data';
  static const _usernameKey = 'pesu_username';
  static const _passwordKey = 'pesu_password';

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

  // -- Widget data sync --

  /// Serialises attendance into a compact JSON blob and pushes it to the
  /// native Android widget through the HomeWidget plugin.
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

    final widgetDataJson = jsonEncode({
      'overall': overallStr,
      'colorLevel': colorLevel,
      'lastUpdated': lastUpdated,
      'subjects': subjectsJsonList,
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
}
