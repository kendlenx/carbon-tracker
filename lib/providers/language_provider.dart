import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'language';
  String _currentLanguage = 'en';

  String get currentLanguage => _currentLanguage;

  bool get isEnglish => _currentLanguage == 'en';
  bool get isTurkish => _currentLanguage == 'tr';

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    _currentLanguage = prefs.getString(_languageKey) ?? 'en';
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    if (language != _currentLanguage) {
      _currentLanguage = language;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, language);
      notifyListeners();
    }
  }

  String getCurrentLanguageDisplayName() {
    switch (_currentLanguage) {
      case 'tr':
        return 'Türkçe';
      case 'en':
      default:
        return 'English';
    }
  }

  String getCurrentLanguageFlag() {
    switch (_currentLanguage) {
      case 'tr':
        return '🇹🇷';
      case 'en':
      default:
        return '🇺🇸';
    }
  }
}