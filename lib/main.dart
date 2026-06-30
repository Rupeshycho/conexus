import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';

import 'package:conexus/firebase_options.dart';
import 'package:conexus/views/login_screen.dart';
import 'package:conexus/views/reset_password_screen.dart';
import 'package:conexus/views/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
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
    return MaterialApp(
      title: 'Conexus',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (_) => LoginScreen(),
      },
    );
  }
}