// lib/repo/user_repo.dart
import '../models/user_model.dart';

abstract class UserRepo {
  Future<List<UserModel>> getSuggestedUsers(String currentUserId);
  Future<List<UserModel>> searchUsers(String query);
}