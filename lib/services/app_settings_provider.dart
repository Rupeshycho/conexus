import 'package:flutter/material.dart';
import 'settings_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  final SettingsService _settingsService = SettingsService();

  ThemeMode _themeMode = ThemeMode.light;
  String _language = "English (US)";

  ThemeMode get themeMode => _themeMode;
  String get language => _language;

  // Call once when app starts
  Future<void> loadSettings() async {
    final isDark = await _settingsService.getDarkMode();
    final lang = await _settingsService.getLanguage();

    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _language = lang;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _themeMode = value ? ThemeMode.dark : ThemeMode.light;
    notifyListeners(); // instantly updates whole app's look
    await _settingsService.setDarkMode(value); // save to Firestore
  }

  Future<void> setLanguage(String language) async {
    _language = language;
    notifyListeners();
    await _settingsService.setLanguage(language); // just save the choice
  }
}