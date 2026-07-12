import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/create_image_post.dart';
import 'screens/create_text_post.dart';
import 'screens/edit_post_screen.dart';
import 'screens/home_screen.dart';
import 'screens/image_feed_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/text_feed_screen.dart';
import 'screens/view_image_post.dart';
import 'screens/view_text_post.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conexus',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/home': (context) => const HomeScreen(),
        '/image_feed': (context) => const ImageFeedScreen(),
        '/text_feed': (context) => const TextFeedScreen(),
        '/view_image_post': (context) => const ViewImagePost(),
        '/view_text_post': (context) => const ViewTextPost(),
        '/create_image': (context) => const CreateImagePostScreen(),
        '/create_text': (context) => const CreateTextPostScreen(),
        '/edit_post': (context) => const EditPostScreen(),
        '/notifications': (context) => const NotificationScreen(),
      },
    );
  }
}
