import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() {
    // We can't be async here in build easily without AsyncValue,
    // but for simple prefs we can load initial state in a separate init or
    // just default to system and update when prefs load.
    // However, better approach for synchronous Notifier is to load in main() or
    // use a separate FutureProvider for prefs.
    // For simplicity, we'll start with System and load prefs immediately.
    _loadTheme();
    return ThemeMode.system;
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      if (saved == 'light')
        state = ThemeMode.light;
      else if (saved == 'dark')
        state = ThemeMode.dark;
      else
        state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    if (mode == ThemeMode.dark) val = 'dark';
    await prefs.setString(_key, val);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);
