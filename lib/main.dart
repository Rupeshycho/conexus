import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'repo/comment_repo.dart';
import 'repo/notification_repo.dart';
import 'repo/post_repo.dart';
import 'repo/user_repo.dart';
import 'services/locator.dart';
import 'view/home_screen.dart';
import 'viewmodel/home_feed_viewmodel.dart';
import 'viewmodel/notification_viewmodel.dart';
import 'viewmodel/search_viewmodel.dart';
import 'viewmodel/suggested_users_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  setupLocator();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Repos exposed directly (used by CommentScreen via context.read<CommentRepo>())
        Provider<PostRepo>.value(value: locator<PostRepo>()),
        Provider<UserRepo>.value(value: locator<UserRepo>()),
        Provider<CommentRepo>.value(value: locator<CommentRepo>()),
        Provider<NotificationRepo>.value(value: locator<NotificationRepo>()),

        // ViewModels
        ChangeNotifierProvider(create: (_) => locator<HomeFeedViewModel>()),
        ChangeNotifierProvider(
          create: (_) => locator<SuggestedUsersViewModel>(),
        ),
        ChangeNotifierProvider(create: (_) => locator<SearchViewModel>()),
        ChangeNotifierProvider(create: (_) => locator<NotificationViewModel>()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: const HomeScreen(),
      ),
    );
  }
}
