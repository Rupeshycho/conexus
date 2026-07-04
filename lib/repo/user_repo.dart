import 'package:conexus/model/user_model.dart';
abstract class UserRepo {
  Future <String> login(String email,String password);
  Future <String> register(String email,String password);
  Future <void> logout();
  Future <void> forgetPassword(String email);

  Future <void> addUser(UserModel userModel);
  Future <void>deleteUser(String id);

  Future <List<UserModel>> getAllUser();
  Future <UserModel> getUserId(String id);
  Future <void> editProfile(UserModel userModel);
  Future <String> uploadProfileImage(String uid, String imagePath);
//syncronus function
//add all feature related functions
//add Future infront of function(for syncronus functions) palaipalo
//blue print of all functions
}