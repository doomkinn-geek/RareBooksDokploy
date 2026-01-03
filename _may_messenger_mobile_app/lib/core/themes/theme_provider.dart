import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Режимы темы
enum ThemeModeOption {
  system,
  light,
  dark,
}

/// Состояние темы
class ThemeState {
  final ThemeModeOption themeMode;
  
  const ThemeState({this.themeMode = ThemeModeOption.system});
  
  ThemeMode get flutterThemeMode {
    switch (themeMode) {
      case ThemeModeOption.system:
        return ThemeMode.system;
      case ThemeModeOption.light:
        return ThemeMode.light;
      case ThemeModeOption.dark:
        return ThemeMode.dark;
    }
  }
  
  ThemeState copyWith({ThemeModeOption? themeMode}) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

/// Notifier для управления темой
class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeModeKey = 'theme_mode';
  
  ThemeNotifier() : super(const ThemeState()) {
    _loadTheme();
  }
  
  /// Загрузить сохраненную тему
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeModeKey) ?? 0;
      state = state.copyWith(
        themeMode: ThemeModeOption.values[themeIndex],
      );
    } catch (e) {
      print('[ThemeNotifier] Error loading theme: $e');
    }
  }
  
  /// Установить режим темы
  Future<void> setThemeMode(ThemeModeOption mode) async {
    state = state.copyWith(themeMode: mode);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, mode.index);
    } catch (e) {
      print('[ThemeNotifier] Error saving theme: $e');
    }
  }
  
  /// Переключить между светлой и темной темой
  Future<void> toggleTheme() async {
    final newMode = state.themeMode == ThemeModeOption.light
        ? ThemeModeOption.dark
        : ThemeModeOption.light;
    await setThemeMode(newMode);
  }
}

/// Provider для темы
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

