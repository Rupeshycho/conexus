import 'package:conexus/view/change_password_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'package:conexus/view/settings_screen.dart';
import 'package:provider/provider.dart';
import 'package:conexus/services/app_settings_provider.dart';

import 'package:conexus/firebase_options.dart';
import 'package:conexus/view/login_screen.dart';
import 'package:conexus/view/reset_password_screen.dart';
import 'package:conexus/view/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final appSettings = AppSettingsProvider();
  await appSettings.loadSettings();

  runApp(
    ChangeNotifierProvider.value(
      value: appSettings,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {
    // Handle links while app is running
    _appLinks.uriLinkStream.listen((Uri uri) {
      _processLink(uri);
    });

    // Handle link when app is opened from a link
    _appLinks.getInitialLink().then((Uri? uri) {
      if (uri != null) {
        _processLink(uri);
      }
    });
  }

  void _processLink(Uri uri) {
    debugPrint("📥 Incoming link: $uri");

    if (uri.queryParameters.containsKey('oobCode') &&
        uri.queryParameters['mode'] == 'resetPassword') {
      final String oobCode = uri.queryParameters['oobCode']!;

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(oobCode: oobCode),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppSettingsProvider>(
      builder: (context, appSettings, child) {
        return MaterialApp(
          title: 'Conexus',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          themeMode: appSettings.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
            scaffoldBackgroundColor: const Color(0xFFF3F2F7),
            cardColor: Colors.white,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepOrange,
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E1E),
            useMaterial3: true,
          ),
          home: const ChangePasswordScreen(),
          routes: {
            '/login': (_) => LoginScreen(),
          },
        );
      },
    );
  }
}