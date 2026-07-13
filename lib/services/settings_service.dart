
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference get _usersCollection => _firestore.collection('users');

  // ---------------- PERSONAL INFO ----------------

  Future<Map<String, dynamic>?> getPersonalInfo() async {
    if (currentUserId == null) return null;
    final doc = await _usersCollection.doc(currentUserId).get();
    return doc.data() as Map<String, dynamic>?;
  }
  Future<void> updatePersonalInfo({
    required String username,
    required String email,
  }) async {
    if (currentUserId == null) return;
    await _usersCollection.doc(currentUserId).set({
      'username': username,
      'email': email,
    }, SetOptions(merge: true));

    await _auth.currentUser?.verifyBeforeUpdateEmail(email);
  }

  // ---------------- CHANGE PASSWORD ----------------

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return "No user logged in";

      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? "Failed to change password";
    }
  }

  // ---------------- PUBLIC PROFILE TOGGLE ----------------

  Future<void> setPublicProfile(bool value) async {
    if (currentUserId == null) return;
    await _usersCollection.doc(currentUserId).set({
      'publicProfile': value,
    }, SetOptions(merge: true));
  }

  Future<bool> getPublicProfile() async {
    if (currentUserId == null) return true;
    final doc = await _usersCollection.doc(currentUserId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['publicProfile'] ?? true;
  }

  // ---------------- DARK MODE TOGGLE ----------------

  Future<void> setDarkMode(bool value) async {
    if (currentUserId == null) return;
    await _usersCollection.doc(currentUserId).set({
      'darkMode': value,
    }, SetOptions(merge: true));
  }

  Future<bool> getDarkMode() async {
    if (currentUserId == null) return false;
    final doc = await _usersCollection.doc(currentUserId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['darkMode'] ?? false;
  }

  // ---------------- LANGUAGE ----------------

  Future<void> setLanguage(String language) async {
    if (currentUserId == null) return;
    await _usersCollection.doc(currentUserId).set({
      'language': language,
    }, SetOptions(merge: true));
  }

  Future<String> getLanguage() async {
    if (currentUserId == null) return "English (US)";
    final doc = await _usersCollection.doc(currentUserId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return data?['language'] ?? "English (US)";
  }

  // ---------------- BLOCKED USERS ----------------

  Future<void> blockUser(String userIdToBlock) async {
    if (currentUserId == null) return;
    await _usersCollection.doc(currentUserId).set({
      'blockedUsers': FieldValue.arrayUnion([userIdToBlock]),
    }, SetOptions(merge: true));
  }

  Future<void> unblockUser(String userIdToUnblock) async {
    if (currentUserId == null) return;
    await _usersCollection.doc(currentUserId).set({
      'blockedUsers': FieldValue.arrayRemove([userIdToUnblock]),
    }, SetOptions(merge: true));
  }

  Future<List<String>> getBlockedUsers() async {
    if (currentUserId == null) return [];
    final doc = await _usersCollection.doc(currentUserId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return List<String>.from(data?['blockedUsers'] ?? []);
  }

  // ---------------- LOGOUT ----------------

  Future<void> logout() async {
    await _auth.signOut();
  }
}