import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Цветовая палитра в стиле Telegram с зеленой темой
class AppColors {
  // === СВЕТЛАЯ ТЕМА ===
  
  /// Основной зеленый цвет (AppBar, кнопки)
  static const Color primaryGreen = Color(0xFF128C7E);
  
  /// Светло-зеленый акцент
  static const Color lightGreen = Color(0xFF25D366);
  
  /// Цвет исходящих сообщений (бледно-зеленый)
  static const Color outgoingBubbleLight = Color(0xFFDCF8C6);
  
  /// Цвет входящих сообщений (белый)
  static const Color incomingBubbleLight = Color(0xFFFFFFFF);
  
  /// Фон чата (светлый с зеленоватым оттенком)
  static const Color chatBackgroundLight = Color(0xFFECE5DD);
  
  /// Фон списка чатов
  static const Color scaffoldBackgroundLight = Color(0xFFFFFFFF);
  
  /// Цвет текста исходящих сообщений
  static const Color outgoingTextLight = Color(0xFF000000);
  
  /// Цвет текста входящих сообщений
  static const Color incomingTextLight = Color(0xFF000000);
  
  /// Цвет времени сообщения
  static const Color messageTimeLight = Color(0xFF667781);
  
  /// Цвет разделителей
  static const Color dividerLight = Color(0xFFE0E0E0);
  
  /// Индикатор онлайн
  static const Color onlineIndicator = Color(0xFF4CAF50);
  
  /// Счетчик непрочитанных
  static const Color unreadBadge = Color(0xFF25D366);
  
  // === ТЕМНАЯ ТЕМА ===
  
  /// Основной зеленый для темной темы
  static const Color primaryGreenDark = Color(0xFF00A884);
  
  /// AppBar в темной теме
  static const Color appBarDark = Color(0xFF1F2C34);
  
  /// Цвет исходящих сообщений (темно-зеленый)
  static const Color outgoingBubbleDark = Color(0xFF005C4B);
  
  /// Цвет входящих сообщений (темно-серый)
  static const Color incomingBubbleDark = Color(0xFF1F2C34);
  
  /// Фон чата (темный)
  static const Color chatBackgroundDark = Color(0xFF0B141A);
  
  /// Фон списка чатов (темный)
  static const Color scaffoldBackgroundDark = Color(0xFF111B21);
  
  /// Цвет текста исходящих сообщений (темная тема)
  static const Color outgoingTextDark = Color(0xFFE9EDEF);
  
  /// Цвет текста входящих сообщений (темная тема)
  static const Color incomingTextDark = Color(0xFFE9EDEF);
  
  /// Цвет времени сообщения (темная тема)
  static const Color messageTimeDark = Color(0xFF8696A0);
  
  /// Цвет разделителей (темная тема)
  static const Color dividerDark = Color(0xFF222D34);
  
  // === ОБЩИЕ ===
  
  /// Цвет галочек "прочитано"
  static const Color readCheckmarks = Color(0xFF34B7F1);
  
  /// Цвет ошибки
  static const Color error = Color(0xFFE53935);
  
  /// Цвет предупреждения
  static const Color warning = Color(0xFFFFA726);
}

class AppTheme {
  /// Светлая тема в стиле Telegram
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Основная цветовая схема
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryGreen,
      primaryContainer: AppColors.lightGreen,
      secondary: AppColors.lightGreen,
      secondaryContainer: AppColors.outgoingBubbleLight,
      surface: AppColors.scaffoldBackgroundLight,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: Colors.black87,
      onError: Colors.white,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: AppColors.scaffoldBackgroundLight,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    
    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey,
    ),
    
    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.lightGreen,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    
    // Cards
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    
    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
      ),
    ),
    
    // Icon
    iconTheme: const IconThemeData(
      color: AppColors.primaryGreen,
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerLight,
      thickness: 0.5,
    ),
    
    // List tiles
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.grey[800],
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    
    // Dialog
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Popup menu
    popupMenuTheme: PopupMenuThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );

  /// Темная тема в стиле Telegram
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Основная цветовая схема
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryGreenDark,
      primaryContainer: AppColors.primaryGreenDark,
      secondary: AppColors.primaryGreenDark,
      secondaryContainer: AppColors.outgoingBubbleDark,
      surface: AppColors.scaffoldBackgroundDark,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.incomingTextDark,
      onError: Colors.white,
    ),
    
    // Scaffold
    scaffoldBackgroundColor: AppColors.scaffoldBackgroundDark,
    
    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.appBarDark,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
    ),
    
    // Bottom Navigation
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.appBarDark,
      selectedItemColor: AppColors.primaryGreenDark,
      unselectedItemColor: Colors.grey[600],
    ),
    
    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryGreenDark,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    
    // Cards
    cardTheme: CardThemeData(
      color: AppColors.incomingBubbleDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.incomingBubbleDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: AppColors.primaryGreenDark, width: 1),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    
    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreenDark,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    ),
    
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreenDark,
      ),
    ),
    
    // Icon
    iconTheme: const IconThemeData(
      color: AppColors.primaryGreenDark,
    ),
    
    // Divider
    dividerTheme: const DividerThemeData(
      color: AppColors.dividerDark,
      thickness: 0.5,
    ),
    
    // List tiles
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    
    // Snackbar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.incomingBubbleDark,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    
    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.scaffoldBackgroundDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    
    // Popup menu
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.incomingBubbleDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  );
}

/// Extension для удобного доступа к цветам сообщений
extension MessageColors on ThemeData {
  /// Цвет исходящего сообщения
  Color get outgoingBubbleColor => brightness == Brightness.light
      ? AppColors.outgoingBubbleLight
      : AppColors.outgoingBubbleDark;
  
  /// Цвет входящего сообщения
  Color get incomingBubbleColor => brightness == Brightness.light
      ? AppColors.incomingBubbleLight
      : AppColors.incomingBubbleDark;
  
  /// Цвет текста исходящего сообщения
  Color get outgoingTextColor => brightness == Brightness.light
      ? AppColors.outgoingTextLight
      : AppColors.outgoingTextDark;
  
  /// Цвет текста входящего сообщения
  Color get incomingTextColor => brightness == Brightness.light
      ? AppColors.incomingTextLight
      : AppColors.incomingTextDark;
  
  /// Цвет времени сообщения
  Color get messageTimeColor => brightness == Brightness.light
      ? AppColors.messageTimeLight
      : AppColors.messageTimeDark;
  
  /// Фон чата
  Color get chatBackgroundColor => brightness == Brightness.light
      ? AppColors.chatBackgroundLight
      : AppColors.chatBackgroundDark;
}
