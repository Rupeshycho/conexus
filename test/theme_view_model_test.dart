import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conexus/viewmodel/theme_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeViewModel Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial theme mode should be light', () async {
      final themeViewModel = ThemeViewModel();
      // Since it's async in constructor, we might need a small delay or use a more robust way to wait for initialization if needed.
      // However, usually it defaults to light before the first microtask.
      expect(themeViewModel.themeMode, ThemeMode.light);
    });

    test('toggleTheme should change theme and save to prefs', () async {
      final themeViewModel = ThemeViewModel();
      
      // Toggle to dark
      themeViewModel.toggleTheme();
      expect(themeViewModel.themeMode, ThemeMode.dark);
      expect(themeViewModel.isDarkMode, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('isDarkMode'), true);

      // Toggle back to light
      themeViewModel.toggleTheme();
      expect(themeViewModel.themeMode, ThemeMode.light);
      expect(themeViewModel.isDarkMode, false);
      expect(prefs.getBool('isDarkMode'), false);
    });
  });
}
