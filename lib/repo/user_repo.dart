import 'package:conexus/model/user_model.dart';

abstract class UserRepo {
  // Auth
  Future<String> login(String email, String password);
  Future<String> register(String email, String password);
  Future<void> logout();
  Future<void> forgetPassword(String email);

  // CRUD
  Future<void> addUser(UserModel userModel);
  Future<void> deleteUser(String id);
  Future<List<UserModel>> getAllUser();
  Future<UserModel> getUserId(String id);
  Future<void> editProfile(UserModel userModel);
  Future<String> uploadProfileImage(String uid, String imagePath);

  // Discovery
  Future<List<UserModel>> getSuggestedUsers(String currentUserId);
  Future<List<UserModel>> searchUsers(String query);

  // Profile / social
  Future<UserModel> getCurrentUser();
  Future<UserModel> getUserById(String uid);
  Future<void> updateProfile(UserModel user);
  Future<void> followUser(String targetUid);
  Future<void> unfollowUser(String targetUid);
  Future<void> blockUser(String targetUid);
  Future<void> unblockUser(String targetUid);
}