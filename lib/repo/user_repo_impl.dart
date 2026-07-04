import 'dart:io';
import 'user_repo.dart';
import 'package:conexus/model/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/services/cloudinary_service.dart';

class UserRepoImpl implements UserRepo {
  final auth = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

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
  Future<void> forgetPassword(String email) {
    return auth.sendPasswordResetEmail(email: email);
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
      throw Exception("Upload Profile Image Failed: $e");
    }
  }
}