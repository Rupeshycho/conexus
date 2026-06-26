import 'package:firebase_auth/firebase_auth.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // LOGIN
  Future<User?> login(String email, String password) async {
    try {
      UserCredential userCredential =
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("🔴 AUTH CODE: ${e.code}");
      print("🔴 AUTH MSG: ${e.message}");
      rethrow;
    }
  }

  // REGISTER
  Future<User?> register(String email, String password) async {
    try {
      UserCredential userCredential =
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print("🔴 REGISTER CODE: ${e.code}");
      rethrow;
    }
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }

  // GET CURRENT USER
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}