import 'package:firebase_auth/firebase_auth.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // LOGIN
  Future<User?> login(
      String email,
      String password,
      ) async {

    UserCredential userCredential =
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return userCredential.user;
  }

  // REGISTER
  Future<User?> register(
      String email,
      String password,
      ) async {

    UserCredential userCredential =
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    return userCredential.user;
  }

  // LOGOUT
  Future<void> logout() async {
    await _auth.signOut();
  }
}