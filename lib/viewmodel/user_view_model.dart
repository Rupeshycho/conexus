import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../model/user_model.dart';
import '../repo/user_repo.dart';
import '../repo/user_repo_impl.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepo _repo = UserRepoImpl();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserModel? currentUser;
  bool isLoading = false;
  String? errorMessage;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  UserViewModel() {
    _listenToUserChanges();
  }

  void _listenToUserChanges() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _userSubscription?.cancel();

    _userSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final userData = snapshot.data()!;
        final updatedUser = UserModel.fromMap(userData);

        currentUser = updatedUser;
        isLoading = false;
        notifyListeners();
      }
    }, onError: (error) {
      print("❌ Real-time listener error: $error");
    });
  }

  Future<void> loadCurrentUser() async {
    if (isLoading) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      currentUser = await _repo.getCurrentUser();
    } catch (e) {
      debugPrint("Error loading user: $e");
      errorMessage = e.toString();
      currentUser = null;
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> updateProfile(UserModel user) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repo.updateProfile(user);
    } catch (e) {
      debugPrint("Error updating profile: $e");
      errorMessage = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  Future<UserModel> getUser(String uid) async {
    return await _repo.getUserById(uid);
  }

  Future<void> follow(String uid) async {
    try {
      await _repo.followUser(uid);
    } catch (e) {
      debugPrint("Error following user: $e");
      rethrow;
    }
  }

  Future<void> unfollow(String uid) async {
    try {
      await _repo.unfollowUser(uid);
    } catch (e) {
      debugPrint("Error unfollowing user: $e");
      rethrow;
    }
  }

  bool isFollowing(String uid) {
    if (currentUser == null) return false;
    return currentUser!.following.contains(uid);
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}