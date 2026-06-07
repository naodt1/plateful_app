import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'theme_mode';

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.light;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kThemeKey);
    if (stored == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> toggle() async {
    final next =
        state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, next == ThemeMode.dark ? 'dark' : 'light');
  }

  bool get isDark => state == ThemeMode.dark;
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
