import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    _loadLocale();
    return const Locale('en');
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('locale_code');
    if (saved != null) {
      state = Locale(saved);
    }
  }

  Future<void> setLocale(Locale? locale) async {
    if (locale != null) {
      state = locale;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale_code', locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);
