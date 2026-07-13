import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static Future<void> saveUser({
    required String uid,
    required String email,
    required String name,
    required String profileImage,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('uid', uid);
    await prefs.setString('email', email);
    await prefs.setString('name', name);
    await prefs.setString('profileImage', profileImage);
    await prefs.setBool('isLoggedIn', true);
  }

  static Future<void> clearUser() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('uid');
    await prefs.remove('email');
    await prefs.remove('name');
    await prefs.remove('profileImage');
    await prefs.setBool('isLoggedIn', false);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  static Future<String?> getUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('uid');
  }

  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('email');
  }

  static Future<String?> getName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('name');
  }

  static Future<String?> getProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('profileImage');
  }
}