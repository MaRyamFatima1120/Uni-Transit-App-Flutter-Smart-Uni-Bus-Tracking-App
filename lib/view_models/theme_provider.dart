import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Provider to hold the SharedPreferences instance
// Throws an error if accessed before being overridden in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'SharedPreferences must be initialized in main.dart',
  );
});

// Using NotifierProvider which is the recommended approach in Riverpod 2.0+
final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';

  @override
  ThemeMode build() {
    // Read the sharedPreferencesProvider.
    // Since it's overridden in main with a value, this is safe and synchronous.
    final prefs = ref.watch(sharedPreferencesProvider);
    final String? themeStr = prefs.getString(_themeKey);

    if (themeStr == 'ThemeMode.light') {
      return ThemeMode.light;
    } else if (themeStr == 'ThemeMode.dark') {
      return ThemeMode.dark;
    } else {
      return ThemeMode.system;
    }
  }

  void toggleTheme(bool isDark) {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    _saveTheme(state);
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    _saveTheme(state);
  }

  void _saveTheme(ThemeMode mode) {
    ref.read(sharedPreferencesProvider).setString(_themeKey, mode.toString());
  }
}
