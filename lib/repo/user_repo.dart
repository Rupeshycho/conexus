import 'package:conexus/model/user_model.dart';

abstract class UserRepo {
  Future<UserModel> getCurrentUser();
  Future<UserModel> getUserById(String uid);
  Future<void> updateProfile(UserModel user);
  Future<void> followUser(String targetUid);
  Future<void> unfollowUser(String targetUid);
}