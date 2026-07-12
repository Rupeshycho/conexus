import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {

  final AuthService _authService = AuthService();

  bool isLoading = false;

  // LOGIN
  Future<void> login(
      String email,
      String password,
      ) async {

    try {

      isLoading = true;
      notifyListeners();

      await _authService.login(email, password);

    } catch (e) {

      print(e);

    } finally {

      isLoading = false;
      notifyListeners();
    }
  }

  // REGISTER
  Future<void> register(
      String email,
      String password,
      ) async {

    try {

      isLoading = true;
      notifyListeners();

      await _authService.register(email, password);

    } catch (e) {

      print(e);

    } finally {

      isLoading = false;
      notifyListeners();
    }
  }
}