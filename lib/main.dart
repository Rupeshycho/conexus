import 'package:conexus/views/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:app_links/app_links.dart';
import 'package:conexus/views/login_screen.dart';
import 'package:conexus/views/reset_password_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _handleIncomingLinks();
  }

  void _handleIncomingLinks() {

    // Handle link when app is already open
    _appLinks.uriLinkStream.listen((uri) {
      _processLink(uri);
    });

    // Handle link when app is opened from link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _processLink(uri);
      }
    });
  }

  void _processLink(Uri uri) {
    print("📥 Incoming link: $uri");

    // Check if it is a Firebase password reset link
    if (uri.queryParameters.containsKey('oobCode') &&
        uri.queryParameters['mode'] == 'resetPassword') {

      final oobCode = uri.queryParameters['oobCode']!;

      // Navigate to custom reset password screen
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ResetPasswordScreen(oobCode: oobCode),
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
    );
  }
}
