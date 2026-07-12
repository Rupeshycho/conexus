import 'package:conexus/firebase_options.dart';
import 'package:conexus/view/other_profile_screen.dart';
import 'package:conexus/view/profile_screen.dart';
import 'package:conexus/viewmodel/image_view_model.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Create test users for development
  try {
    await createTestUsers();
    debugPrint("✅ Test users created successfully.");
  } catch (e) {
    debugPrint("⚠️ Could not create test users: $e");
    debugPrint("ℹ️ The app will still work using fallback test user.");
  }

  // ✅ Create test notifications
  try {
    await createTestNotifications();
    debugPrint("✅ Test notifications created successfully.");
  } catch (e) {
    debugPrint("⚠️ Could not create test notifications: $e");
  }

  runApp(const ConexusApp());
}

Future<void> createTestUsers() async {
  final firestore = FirebaseFirestore.instance;

  // ✅ User 1 - Alvaroo (You)
  await firestore.collection('users').doc('test_user_123').set({
    "uid": "test_user_123",
    "name": "Alvaroo",
    "username": "heyboyyy",
    "bio": "Software Developer | Flutter Enthusiast",
    "profileImage": "",
    "followers": ['test_user_456', 'test_user_789'],
    "following": ['test_user_456', 'test_user_789'],
  }, SetOptions(merge: true));

  // ✅ User 2 - John Doe (Follower & Following)
  await firestore.collection('users').doc('test_user_456').set({
    "uid": "test_user_456",
    "name": "John Doe",
    "username": "test_user_456",
    "bio": "Flutter Developer | UI/UX Designer",
    "profileImage": "",
    "followers": ['test_user_123'],
    "following": ['test_user_123'],
  }, SetOptions(merge: true));

  // ✅ User 3 - Sarah Smith (Another Follower)
  await firestore.collection('users').doc('test_user_789').set({
    "uid": "test_user_789",
    "name": "Sarah Smith",
    "username": "test_user_789",
    "bio": "Content Creator | Photographer",
    "profileImage": "",
    "followers": ['test_user_123'],
    "following": ['test_user_123'],
  }, SetOptions(merge: true));

  debugPrint("✅ Test users created in Firestore!");
}

Future<void> createTestNotifications() async {
  final firestore = FirebaseFirestore.instance;
  final userUid = 'test_user_123';  // ✅ Alvaroo's UID

  // Clear old notifications
  final oldNotifs = await firestore
      .collection('users')
      .doc(userUid)
      .collection('notifications')
      .get();
  for (var doc in oldNotifs.docs) {
    await doc.reference.delete();
  }

  // ✅ Create test follow notification (John Doe)
  await firestore
      .collection('users')
      .doc(userUid)
      .collection('notifications')
      .add({
    'type': 'follow',
    'message': 'John Doe started following you',
    'fromUid': 'test_user_456',
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });

  // ✅ Create test follow notification (Sarah Smith)
  await firestore
      .collection('users')
      .doc(userUid)
      .collection('notifications')
      .add({
    'type': 'follow',
    'message': 'Sarah Smith started following you',
    'fromUid': 'test_user_789',
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });

  // ❌ REMOVED: Sarah Smith unfollowed you

  debugPrint("✅ Test notifications created for $userUid");
}

class ConexusApp extends StatelessWidget {
  const ConexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<UserViewModel>(
          create: (_) => UserViewModel(),
        ),
        ChangeNotifierProvider<ImageViewModel>(
          create: (_) => ImageViewModel(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Conexus',
        theme: ThemeData(
          primarySwatch: Colors.deepOrange,
        ),
        initialRoute: '/',
        routes: {
          '/': (context) => const ProfileScreen(),
          '/otherProfile': (context) => OtherProfileScreen(
            userId: ModalRoute.of(context)!.settings.arguments as String,
          ),
        },
      ),
    );
  }
}