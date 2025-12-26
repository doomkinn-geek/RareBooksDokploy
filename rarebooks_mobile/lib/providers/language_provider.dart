import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// Language provider for managing app localization
class LanguageProvider extends ChangeNotifier {
  final StorageService _storageService;
  
  Locale _locale = const Locale('ru');
  
  LanguageProvider({required StorageService storageService})
      : _storageService = storageService {
    _loadSavedLanguage();
  }
  
  /// Current locale
  Locale get locale => _locale;
  
  /// Current language code
  String get languageCode => _locale.languageCode;
  
  /// Is Russian language
  bool get isRussian => _locale.languageCode == 'ru';
  
  /// Is English language
  bool get isEnglish => _locale.languageCode == 'en';
  
  /// Supported locales
  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('en'),
  ];
  
  /// Load saved language from storage
  void _loadSavedLanguage() {
    final savedLanguage = _storageService.getLanguage();
    _locale = Locale(savedLanguage);
    notifyListeners();
  }
  
  /// Set language
  Future<void> setLanguage(String languageCode) async {
    if (languageCode != _locale.languageCode) {
      _locale = Locale(languageCode);
      await _storageService.saveLanguage(languageCode);
      notifyListeners();
    }
  }
  
  /// Toggle between Russian and English
  Future<void> toggleLanguage() async {
    if (isRussian) {
      await setLanguage('en');
    } else {
      await setLanguage('ru');
    }
  }
}

