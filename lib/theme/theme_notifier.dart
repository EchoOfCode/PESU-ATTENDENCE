import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'app_theme.dart';

class ThemeNotifier extends ValueNotifier<AppTheme> {
  static final ThemeNotifier instance = ThemeNotifier._();
  
  ThemeNotifier._() : super(AppTheme.defaultTheme) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString('app_theme') ?? 'default';
    if (themeName == 'funny') {
      value = AppTheme.funnyTheme;
    } else if (themeName == 'cute') {
      value = AppTheme.cuteTheme;
    } else {
      value = AppTheme.defaultTheme;
    }
  }

  Future<void> setTheme(AppThemeType type) async {
    final prefs = await SharedPreferences.getInstance();
    if (type == AppThemeType.funny) {
      value = AppTheme.funnyTheme;
      await prefs.setString('app_theme', 'funny');
    } else if (type == AppThemeType.cute) {
      value = AppTheme.cuteTheme;
      await prefs.setString('app_theme', 'cute');
    } else {
      value = AppTheme.defaultTheme;
      await prefs.setString('app_theme', 'default');
    }
    
    // Sync theme to widget
    try {
      await HomeWidget.updateWidget(
        name: 'AttendanceWidgetProvider',
        iOSName: 'AttendanceWidget',
      );
    } catch (_) {}
  }
}
