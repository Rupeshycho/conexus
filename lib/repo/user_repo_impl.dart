// lib/repo/user_repo_impl.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'user_repo.dart';

class UserRepoImpl implements UserRepo {
  final FirebaseFirestore _firestore;

  UserRepoImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<List<UserModel>> getSuggestedUsers(String currentUserId) async {
    // Simple version: latest 15 users, excluding yourself.
    // (Later you can improve this to exclude users you already follow.)
    final snapshot = await _firestore
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(15)
        .get();

    return snapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .where((user) => user.uid != currentUserId)
        .toList();
  }

  @override
  Future<List<UserModel>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();
    final snapshot = await _firestore
        .collection('users')
        .orderBy('username')
        .startAt([lowerQuery])
        .endAt(['$lowerQuery\uf8ff'])
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }
}