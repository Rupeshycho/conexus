import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/repo/comment_repo.dart';
import 'package:conexus/repo/comment_repo_impl.dart';
import 'package:conexus/repo/notification_repo.dart';
import 'package:conexus/repo/notification_repo_impl.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:conexus/repo/post_repo_impl.dart';
// Repositories
import 'package:conexus/repo/user_repo_impl.dart';
// Services
import 'package:conexus/services/notification_service.dart';
// Screens
import 'package:conexus/view/login_screen.dart';
import 'package:conexus/view/register.dart';
import 'package:conexus/view/send_message.dart';
import 'package:conexus/view/splash_screen.dart';
import 'package:conexus/viewmodel/auth_viewmodel.dart';
import 'package:conexus/viewmodel/home_feed_viewmodel.dart';
import 'package:conexus/viewmodel/image_view_model.dart';
import 'package:conexus/viewmodel/notification_viewmodel.dart';
import 'package:conexus/viewmodel/suggested_users_viewmodel.dart';
import 'package:conexus/viewmodel/theme_view_model.dart';
// ViewModels
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Explicit offline persistence config. Persistence is on by default on
  // iOS/Android, but setting it explicitly here makes the behavior clear
  // and lets us control cache size instead of relying on the default.
  // Must run before any Firestore reads/writes happen elsewhere in the app.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 2. Set up background messaging handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 3. Initialize Notification Service
  final notificationService = NotificationService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ThemeViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => UserViewModel(userRepo: UserRepoImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => NotificationViewModel(NotificationRepoImpl()),
        ),
        ChangeNotifierProvider(
          create: (_) => ImageViewModel(),
        ),
        ChangeNotifierProvider(
          create: (_) => SuggestedUsersViewModel(UserRepoImpl()),
        ),

        // Single shared NotificationRepo — both PostRepo and CommentRepo
        // depend on this, so it's registered once here and reused below.
        Provider<NotificationRepo>(
          create: (_) => NotificationRepoImpl(),
        ),

        // PostRepo needs NotificationRepo (to notify post owners on likes),
        // so it's built via ProxyProvider off the NotificationRepo above.
        ProxyProvider<NotificationRepo, PostRepo>(
          update: (_, notificationRepo, __) =>
              PostRepoImpl(notificationRepo: notificationRepo),
        ),

        // HomeFeedViewModel depends on PostRepo, plus the current viewer's
        // uid (needed so the feed can filter out private accounts the
        // viewer doesn't follow). `previous ?? ...` ensures the
        // ChangeNotifier is only constructed once, not rebuilt every time
        // PostRepo's ProxyProvider re-evaluates.
        ChangeNotifierProxyProvider<PostRepo, HomeFeedViewModel>(
          create: (context) => HomeFeedViewModel(
            context.read<PostRepo>(),
            FirebaseAuth.instance.currentUser?.uid ?? '',
          ),
          update: (_, postRepo, previous) =>
              previous ??
              HomeFeedViewModel(
                postRepo,
                FirebaseAuth.instance.currentUser?.uid ?? '',
              ),
        ),

        // CommentRepo needs NotificationRepo (to notify post owners on
        // comments), same pattern as PostRepo above.
        ProxyProvider<NotificationRepo, CommentRepo>(
          update: (_, notificationRepo, __) =>
              CommentRepoImpl(notificationRepo: notificationRepo),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeViewModel = context.watch<ThemeViewModel>();

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Conexus',
      debugShowCheckedModeBanner: false,
      themeMode: themeViewModel.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      // Splash screen is now the entry point; it's expected to hand off
      // to AuthWrapper (below) once its intro/delay logic finishes, so
      // the real auth-state routing is unchanged.
      home: const SplashScreen(),
      routes: {
        '/register': (context) => SignupScreen(),
        '/login': (context) => LoginScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  /// Injectable so widget tests can supply a fake auth state stream
  /// instead of the real FirebaseAuth plugin (which has no platform
  /// implementation under `flutter test` and would throw
  /// `[core/no-app]` / `MissingPluginException`). Defaults to the real
  /// stream in production — existing call sites are unaffected.
  final Stream<User?>? authStateStream;

  const AuthWrapper({super.key, this.authStateStream});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authStateStream ?? FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If checking auth state, show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Colors.orange),
            ),
          );
        }

        // If logged in, show Chat List (MessageFrame)
        if (snapshot.hasData) {
          return const MessageFrame();
        }

        // Otherwise, show Login
        return SplashScreen();
      },
    );
  }
}
