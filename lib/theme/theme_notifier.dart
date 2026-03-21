import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';
import 'app_theme.dart';

/// Singleton that holds the active [AppTheme] and persists the choice.
/// Widgets listen to this via [ValueListenableBuilder] for instant redraws.
class ThemeNotifier extends ValueNotifier<AppTheme> {
  static final ThemeNotifier instance = ThemeNotifier._();

  ThemeNotifier._() : super(AppTheme.defaultTheme) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('app_theme') ?? 'default';
    if (name == 'funny') {
      value = AppTheme.funnyTheme;
    } else if (name == 'cute') {
      value = AppTheme.cuteTheme;
    } else {
      value = AppTheme.defaultTheme;
    }
  }

  Future<void> setTheme(AppThemeType type) async {
    final prefs = await SharedPreferences.getInstance();
    switch (type) {
      case AppThemeType.funny:
        value = AppTheme.funnyTheme;
        await prefs.setString('app_theme', 'funny');
      case AppThemeType.cute:
        value = AppTheme.cuteTheme;
        await prefs.setString('app_theme', 'cute');
      case AppThemeType.defaultTheme:
        value = AppTheme.defaultTheme;
        await prefs.setString('app_theme', 'default');
    }

    // Push updated theme to the native widget immediately.
    try {
      await HomeWidget.updateWidget(
        name: 'AttendanceWidgetProvider',
        iOSName: 'AttendanceWidget',
      );
    } catch (_) {}
  }
}
