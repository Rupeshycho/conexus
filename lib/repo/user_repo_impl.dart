// lib/repo/user_repo_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../model/user_model.dart';
import 'user_repo.dart';

class UserRepoImpl implements UserRepo {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  UserModel _getTestUser() {
    return UserModel(
      uid: 'test_user_123',
      name: 'Alvaroo',
      username: 'heyboyyy',
      bio: 'Software Developer | Flutter Enthusiast',
      profileImage: '',
      followers: ['test_user_456'],
      following: ['test_user_456'],
    );
  }

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
        await firestore.collection("users").doc(uid).set({
          "uid": uid,
          "name": user.displayName ?? "User",
          "username": user.email?.split('@').first ?? 'user',
          "bio": "",
          "profileImage": "",
          "followers": [],
          "following": [],
          "email": user.email,
        });
        final newDoc = await firestore.collection("users").doc(uid).get();
        return UserModel.fromMap(newDoc.data()!);
      }

      // Fallback: use test user from Firestore or create if missing
      final testUid = 'test_user_123';
      final testDoc = await firestore.collection("users").doc(testUid).get();
      if (testDoc.exists) {
        return UserModel.fromMap(testDoc.data()!);
      }
      // If still not, create in Firestore (but if permission denied, return hardcoded)
      try {
        await firestore.collection("users").doc(testUid).set({
          "uid": testUid,
          "name": "Alvaroo",
          "username": "heyboyyy",
          "bio": "Software Developer | Flutter Enthusiast",
          "profileImage": "",
          "followers": ['test_user_456'],
          "following": ['test_user_456'],
        });
        final newTestDoc = await firestore.collection("users").doc(testUid).get();
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
        uid: uid,
        name: 'User $uid',
        username: 'user$uid',
        bio: 'This is a test user',
        profileImage: '',
        followers: [],
        following: [],
      );
    }
  }

  @override
  Future<void> updateProfile(UserModel user) async {
    try {
      await firestore.collection("users").doc(user.uid).set({
        "uid": user.uid,
        "name": user.name,
        "username": user.username,
        "bio": user.bio,
        "profileImage": user.profileImage,
        "followers": user.followers,
        "following": user.following,
      }, SetOptions(merge: true));
      debugPrint("✅ Profile updated for: ${user.uid}");
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

      // ✅ Update following/followers
      await firestore.collection("users").doc(myUid).update({
        "following": FieldValue.arrayUnion([targetUid])
      });
      await firestore.collection("users").doc(targetUid).update({
        "followers": FieldValue.arrayUnion([myUid])
      });

      // ✅ Add FOLLOW notification
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

      // ✅ Update following/followers
      await firestore.collection("users").doc(myUid).update({
        "following": FieldValue.arrayRemove([targetUid])
      });
      await firestore.collection("users").doc(targetUid).update({
        "followers": FieldValue.arrayRemove([myUid])
      });

      // ✅ Delete old follow notification
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

      // ✅ Add UNFOLLOW notification
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
}