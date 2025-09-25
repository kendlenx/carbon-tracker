import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;

class LanguageService extends ChangeNotifier {
  static LanguageService? _instance;
  static LanguageService get instance => _instance ??= LanguageService._();
  
  LanguageService._();

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('tr', 'TR'), // Turkish (default)
    Locale('en', 'US'), // English
  ];

  // Current locale
  Locale _currentLocale = const Locale('tr', 'TR'); // Default to Turkish
  bool _isInitialized = false;

  // Getters
  Locale get currentLocale => _currentLocale;
  bool get isInitialized => _isInitialized;
  bool get isEnglish => _currentLocale.languageCode == 'en';
  bool get isTurkish => _currentLocale.languageCode == 'tr';
  String get currentLanguageCode => _currentLocale.languageCode;
  String get currentCountryCode => _currentLocale.countryCode ?? '';

  /// Initialize language service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _loadSavedLanguage();
    _isInitialized = true;
    notifyListeners();
  }

  /// Load saved language preference or detect system language
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguageCode = prefs.getString('selected_language');

      if (savedLanguageCode != null) {
        // Use saved language preference
        _currentLocale = _getLocaleFromLanguageCode(savedLanguageCode);
      } else {
        // Auto-detect system language, default to Turkish if not supported
        final systemLocale = ui.window.locale;
        if (_isSupportedLocale(systemLocale)) {
          _currentLocale = systemLocale;
        } else {
          // Default to Turkish if system language is not supported
          _currentLocale = const Locale('tr', 'TR');
        }
        // Save the detected/default language
        await _saveLanguagePreference(_currentLocale.languageCode);
      }
    } catch (e) {
      print('Error loading language preference: $e');
      _currentLocale = const Locale('tr', 'TR'); // Fallback to Turkish
    }
  }

  /// Check if locale is supported
  bool _isSupportedLocale(Locale locale) {
    return supportedLocales.any((supportedLocale) => 
        supportedLocale.languageCode == locale.languageCode);
  }

  /// Get locale from language code
  Locale _getLocaleFromLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'en':
        return const Locale('en', 'US');
      case 'tr':
      default:
        return const Locale('tr', 'TR');
    }
  }

  /// Change language
  Future<void> changeLanguage(String languageCode) async {
    if (_currentLocale.languageCode == languageCode) return;

    _currentLocale = _getLocaleFromLanguageCode(languageCode);
    await _saveLanguagePreference(languageCode);
    notifyListeners();
  }
  
  /// Alias for changeLanguage - for consistency
  Future<void> setLanguage(String languageCode) async {
    await changeLanguage(languageCode);
  }

  /// Toggle between Turkish and English
  Future<void> toggleLanguage() async {
    final newLanguageCode = _currentLocale.languageCode == 'tr' ? 'en' : 'tr';
    await changeLanguage(newLanguageCode);
  }

  /// Save language preference
  Future<void> _saveLanguagePreference(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_language', languageCode);
    } catch (e) {
      print('Error saving language preference: $e');
    }
  }

  /// Get language display name
  String getLanguageDisplayName(String languageCode) {
    switch (languageCode) {
      case 'tr':
        return 'Türkçe';
      case 'en':
        return 'English';
      default:
        return 'Türkçe';
    }
  }

  /// Get current language display name
  String get currentLanguageDisplayName {
    return getLanguageDisplayName(_currentLocale.languageCode);
  }

  /// Get language flag emoji
  String getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'tr':
        return '🇹🇷';
      case 'en':
        return '🇺🇸';
      default:
        return '🇹🇷';
    }
  }

  /// Get current language flag
  String get currentLanguageFlag {
    return getLanguageFlag(_currentLocale.languageCode);
  }
}