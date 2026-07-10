// lib/services/firebase_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static FirebaseAuth get auth => FirebaseAuth.instance;

  /// Currently logged-in user's UID, or null if not logged in.
  static String? get currentUserId => auth.currentUser?.uid;

  /// Currently logged-in user's email, or null if not logged in.
  static String? get currentUserEmail => auth.currentUser?.email;

  static bool get isLoggedIn => auth.currentUser != null;
}
