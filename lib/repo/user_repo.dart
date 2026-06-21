import 'package:conexus/model/user_model.dart';


abstract class UserRepo {
  Future<void> createUser(UserModel user);
  Future<UserModel> getUser(String uid);
  Future<void> updateUser(UserModel user);
  Future<void> followUser(String myUid, String targetUid);
  Future<void> unfollowUser(String myUid, String targetUid);
}