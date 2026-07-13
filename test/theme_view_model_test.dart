import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conexus/viewmodel/theme_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeViewModel's constructor kicks off `_loadThemeFromPrefs()` and
/// `toggleTheme()` kicks off `_saveThemeToPrefs()` without awaiting either
/// — both are fire-and-forget. That means `themeMode` briefly still holds
/// the pre-load/pre-save value right after calling the constructor or
/// `toggleTheme()`. This `flushMicrotasks()` helper gives one pending
/// microtask a turn to run (enough for `SharedPreferences.getInstance()`
/// under the mock implementation to resolve) so tests observe the
/// settled state instead of racing it.
Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeViewModel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to light mode synchronously, before prefs finish loading',
            () {
          final themeViewModel = ThemeViewModel();

          expect(themeViewModel.themeMode, ThemeMode.light);
          expect(themeViewModel.isDarkMode, false);
        });

    test('stays light after loading completes with no saved preference',
            () async {
          final themeViewModel = ThemeViewModel();
          await flushMicrotasks();

          expect(themeViewModel.themeMode, ThemeMode.light);
          expect(themeViewModel.isDarkMode, false);
        });

    test('loads dark mode once a previously-saved preference resolves',
            () async {
          SharedPreferences.setMockInitialValues({'isDarkMode': true});
          final themeViewModel = ThemeViewModel();

          // Still light immediately after construction — the load hasn't
          // resolved yet.
          expect(themeViewModel.themeMode, ThemeMode.light);

          var notified = false;
          themeViewModel.addListener(() => notified = true);
          await flushMicrotasks();

          expect(notified, true);
          expect(themeViewModel.themeMode, ThemeMode.dark);
          expect(themeViewModel.isDarkMode, true);
        });

    test('toggleTheme flips themeMode/isDarkMode and notifies listeners',
            () async {
          final themeViewModel = ThemeViewModel();
          await flushMicrotasks(); // let the initial load settle first

          var notifyCount = 0;
          themeViewModel.addListener(() => notifyCount++);

          themeViewModel.toggleTheme();
          expect(themeViewModel.themeMode, ThemeMode.dark);
          expect(themeViewModel.isDarkMode, true);
          expect(notifyCount, 1);

          themeViewModel.toggleTheme();
          expect(themeViewModel.themeMode, ThemeMode.light);
          expect(themeViewModel.isDarkMode, false);
          expect(notifyCount, 2);
        });

    test('toggleTheme persists the new value to SharedPreferences',
            () async {
          final themeViewModel = ThemeViewModel();
          await flushMicrotasks();

          themeViewModel.toggleTheme(); // -> dark
          await flushMicrotasks(); // let the fire-and-forget save resolve

          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getBool('isDarkMode'), true);

          themeViewModel.toggleTheme(); // -> light
          await flushMicrotasks();

          expect(prefs.getBool('isDarkMode'), false);
        });

    test('alternates correctly across repeated toggles', () async {
      final themeViewModel = ThemeViewModel();
      await flushMicrotasks();

      for (var i = 0; i < 4; i++) {
        themeViewModel.toggleTheme();
        final expectedDark = i.isEven; // light -> dark -> light -> dark -> light
        expect(themeViewModel.isDarkMode, expectedDark);
      }

      await flushMicrotasks();
    });

    test('a fresh ThemeViewModel picks up a preference saved by a previous instance',
            () async {
          final first = ThemeViewModel();
          await flushMicrotasks();

          first.toggleTheme(); // -> dark, persisted
          await flushMicrotasks();

          final second = ThemeViewModel();
          await flushMicrotasks();

          expect(second.themeMode, ThemeMode.dark);
          expect(second.isDarkMode, true);
        });
  });
}
