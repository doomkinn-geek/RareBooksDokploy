import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

/// Режимы темы
enum ThemeModeOption {
  system,
  light,
  dark,
}

/// Состояние темы
class ThemeState {
  final ThemeModeOption themeMode;
  final DesignStyle designStyle;
  
  const ThemeState({
    this.themeMode = ThemeModeOption.system,
    this.designStyle = DesignStyle.green,
  });
  
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
  
  /// Получить светлую тему в зависимости от выбранного дизайна
  ThemeData get lightTheme {
    switch (designStyle) {
      case DesignStyle.green:
        return AppTheme.lightTheme;
      case DesignStyle.slate:
        return AppTheme.slateLightTheme;
    }
  }
  
  /// Получить темную тему в зависимости от выбранного дизайна
  ThemeData get darkTheme {
    switch (designStyle) {
      case DesignStyle.green:
        return AppTheme.darkTheme;
      case DesignStyle.slate:
        return AppTheme.slateDarkTheme;
    }
  }
  
  ThemeState copyWith({
    ThemeModeOption? themeMode,
    DesignStyle? designStyle,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      designStyle: designStyle ?? this.designStyle,
    );
  }
}

/// Notifier для управления темой
class ThemeNotifier extends StateNotifier<ThemeState> {
  static const String _themeModeKey = 'theme_mode';
  static const String _designStyleKey = 'design_style';
  
  ThemeNotifier() : super(const ThemeState()) {
    _loadTheme();
  }
  
  /// Загрузить сохраненные настройки темы
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(_themeModeKey) ?? 0;
      final designIndex = prefs.getInt(_designStyleKey) ?? 0;
      
      state = state.copyWith(
        themeMode: ThemeModeOption.values[themeIndex.clamp(0, ThemeModeOption.values.length - 1)],
        designStyle: DesignStyle.values[designIndex.clamp(0, DesignStyle.values.length - 1)],
      );
    } catch (e) {
      print('[ThemeNotifier] Error loading theme: $e');
    }
  }
  
  /// Установить режим темы (светлая/темная/системная)
  Future<void> setThemeMode(ThemeModeOption mode) async {
    state = state.copyWith(themeMode: mode);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themeModeKey, mode.index);
    } catch (e) {
      print('[ThemeNotifier] Error saving theme mode: $e');
    }
  }
  
  /// Установить дизайн-стиль (зеленый/серый)
  Future<void> setDesignStyle(DesignStyle style) async {
    state = state.copyWith(designStyle: style);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_designStyleKey, style.index);
    } catch (e) {
      print('[ThemeNotifier] Error saving design style: $e');
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
