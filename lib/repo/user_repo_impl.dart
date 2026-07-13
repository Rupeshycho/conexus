import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'package:conexus/model/user_model.dart';
import 'package:conexus/services/cloudinary_service.dart';
import 'user_repo.dart';

class UserRepoImpl implements UserRepo {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  UserRepoImpl({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance;

  UserModel _getTestUser() {
    return UserModel(
      id: 'test_user_123',
      name: 'Alvaroo',
      username: 'heyboyyy',
      bio: 'Software Developer | Flutter Enthusiast',
      profileImage: '',
      followers: const ['test_user_456'],
      following: const ['test_user_456'],
    );
  }

  // ── Auth ──────────────────────────────────────────────

  @override
  Future<String> login(String email, String password) async {
    final userCredential = await auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final userId = userCredential.user?.uid;
    if (userId == null) {
      throw Exception("Login Failed");
    }
    return userId;
  }

  @override
  Future<void> logout() {
    return auth.signOut();
  }

  @override
  Future<String> register(String email, String password) async {
    final userCredential = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final userId = userCredential.user?.uid;
    if (userId == null) {
      throw Exception("Registration Failed");
    }
    return userId;
  }

  @override
  Future<void> forgetPassword(String email) {
    return auth.sendPasswordResetEmail(email: email);
  }

  // ── CRUD ──────────────────────────────────────────────

  @override
  Future<void> addUser(UserModel userModel) {
    return firestore
        .collection("users")
        .doc(userModel.id)
        .set(userModel.toMap());
  }

  @override
  Future<void> deleteUser(String id) {
    return firestore.collection("users").doc(id).delete();
  }

  @override
  Future<void> editProfile(UserModel userModel) {
    return firestore
        .collection("users")
        .doc(userModel.id)
        .set(userModel.toMap(), SetOptions(merge: true));
  }

  @override
  Future<List<UserModel>> getAllUser() async {
    final querySnapshot = await firestore.collection("users").get();
    return querySnapshot.docs
        .map((doc) => UserModel.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<UserModel> getUserId(String id) async {
    final docSnapshot = await firestore.collection("users").doc(id).get();
    final data = docSnapshot.data();
    if (data == null) {
      throw Exception("unable to fetch data");
    }
    return UserModel.fromMap(data);
  }

  @override
  Future<String> uploadProfileImage(String uid, String imagePath) async {
    try {
      final file = File(imagePath);
      final downloadUrl = await CloudinaryService.uploadImage(file);
      if (downloadUrl != null) {
        return downloadUrl;
      } else {
        throw Exception("Cloudinary upload failed");
      }
    } catch (e) {
      throw Exception("Upload Profile images Failed: $e");
    }
  }

  // ── Discovery ─────────────────────────────────────────

  /// Latest 15 users, excluding the current one.
  @override
  Future<List<UserModel>> getSuggestedUsers(String currentUserId) async {
    final snapshot = await firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(15)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where((user) => user.id != currentUserId)
        .toList();
  }

  /// Prefix search over `name` (matches `toMap()`'s lowercased storage
  /// convention only if you lowercase `name` before saving — otherwise
  /// lowercase the stored field too, or this range query won't match).
  @override
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final snapshot = await firestore
        .collection('users')
        .orderBy('name')
        .startAt([lowerQuery])
        .endAt(['$lowerQuery\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // ── Profile / social ──────────────────────────────────

  @override
  Future<UserModel> getCurrentUser() async {
    try {
      final user = auth.currentUser;

      if (user != null) {
        final uid = user.uid;
        final doc = await firestore.collection("users").doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data()!);
        }
        // Auto-create if missing
        final newUser = UserModel(
          id: uid,
          name: user.displayName ?? "User",
          username: user.email?.split('@').first ?? 'user',
          email: user.email ?? '',
        );
        await firestore.collection("users").doc(uid).set(newUser.toMap());
        final newDoc = await firestore.collection("users").doc(uid).get();
        return UserModel.fromMap(newDoc.data()!);
      }

      // Fallback: use test user from Firestore or create if missing
      const testUid = 'test_user_123';
      final testDoc = await firestore.collection("users").doc(testUid).get();
      if (testDoc.exists) {
        return UserModel.fromMap(testDoc.data()!);
      }
      // If still not, create in Firestore (but if permission denied, return hardcoded)
      try {
        final testUser = _getTestUser();
        await firestore.collection("users").doc(testUid).set(testUser.toMap());
        final newTestDoc =
        await firestore.collection("users").doc(testUid).get();
        return UserModel.fromMap(newTestDoc.data()!);
      } catch (_) {
        // If still failing, return hardcoded test user
        return _getTestUser();
      }
    } catch (e) {
      debugPrint("❌ Error loading user: $e");
      return _getTestUser();
    }
  }

  @override
  Future<UserModel> getUserById(String uid) async {
    try {
      final doc = await firestore.collection("users").doc(uid).get();
      if (!doc.exists) throw Exception("User not found");
      return UserModel.fromMap(doc.data()!);
    } catch (e) {
      debugPrint("❌ Error loading user by ID: $e");
      return UserModel(
        id: uid,
        name: 'User $uid',
        username: 'user$uid',
        bio: 'This is a test user',
      );
    }
  }

  @override
  Future<void> updateProfile(UserModel user) async {
    try {
      await firestore
          .collection("users")
          .doc(user.id)
          .set(user.toMap(), SetOptions(merge: true));
      debugPrint("✅ Profile updated for: ${user.id}");
    } catch (e) {
      debugPrint("❌ Error updating profile: $e");
      rethrow;
    }
  }

  @override
  Future<void> followUser(String targetUid) async {
    try {
      final myUid = auth.currentUser?.uid ?? 'test_user_123';
      final myName = auth.currentUser?.displayName ?? 'Alvaroo';

      await firestore.collection("users").doc(myUid).update({
        "following": FieldValue.arrayUnion([targetUid])
      });
      await firestore.collection("users").doc(targetUid).update({
        "followers": FieldValue.arrayUnion([myUid])
      });

      await firestore
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .add({
        'type': 'follow',
        'message': '$myName started following you',
        'fromUid': myUid,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Followed user: $targetUid");
      debugPrint("✅ Follow notification sent to: $targetUid");
    } catch (e) {
      debugPrint("❌ Error following user: $e");
      rethrow;
    }
  }

  @override
  Future<void> unfollowUser(String targetUid) async {
    try {
      final myUid = auth.currentUser?.uid ?? 'test_user_123';
      final myName = auth.currentUser?.displayName ?? 'Alvaroo';

      await firestore.collection("users").doc(myUid).update({
        "following": FieldValue.arrayRemove([targetUid])
      });
      await firestore.collection("users").doc(targetUid).update({
        "followers": FieldValue.arrayRemove([myUid])
      });

      final oldNotifications = await firestore
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .where('fromUid', isEqualTo: myUid)
          .where('type', isEqualTo: 'follow')
          .get();
      for (var doc in oldNotifications.docs) {
        await doc.reference.delete();
      }

      await firestore
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .add({
        'type': 'unfollow',
        'message': '$myName unfollowed you',
        'fromUid': myUid,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint("✅ Unfollowed user: $targetUid");
      debugPrint("✅ Unfollow notification sent to: $targetUid");
    } catch (e) {
      debugPrint("❌ Error unfollowing user: $e");
      rethrow;
    }
  }
  @override
  Future<void> blockUser(String targetUid) async {
    try {
      final myUid = auth.currentUser?.uid ?? 'test_user_123';

      await firestore.collection("users").doc(myUid).update({
        "blockedUsers": FieldValue.arrayUnion([targetUid]),
        // Blocking implies unfollowing both ways.
        "following": FieldValue.arrayRemove([targetUid]),
        "followers": FieldValue.arrayRemove([targetUid]),
      });
      await firestore.collection("users").doc(targetUid).update({
        "followers": FieldValue.arrayRemove([myUid]),
        "following": FieldValue.arrayRemove([myUid]),
      });

      debugPrint("✅ Blocked user: $targetUid");
    } catch (e) {
      debugPrint("❌ Error blocking user: $e");
      rethrow;
    }
  }

  @override
  Future<void> unblockUser(String targetUid) async {
    try {
      final myUid = auth.currentUser?.uid ?? 'test_user_123';

      await firestore.collection("users").doc(myUid).update({
        "blockedUsers": FieldValue.arrayRemove([targetUid]),
      });

      debugPrint("✅ Unblocked user: $targetUid");
    } catch (e) {
      debugPrint("❌ Error unblocking user: $e");
      rethrow;
    }
  }
}