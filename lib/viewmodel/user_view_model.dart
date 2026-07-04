import 'package:flutter/material.dart';
import 'package:conexus/model/user_model.dart';
import 'package:conexus/repo/user_repo.dart';

class UserViewModel extends ChangeNotifier {
  final UserRepo _userRepo;

  UserViewModel({required UserRepo userRepo}) : _userRepo = userRepo;

  String? _error = "";
  String? get error => _error;

  bool _loading = false;
  bool get loading => _loading;

  UserModel? _user;
  UserModel? get user => _user;

  List<UserModel>? _allUsers;
  List<UserModel>? get allUsers => _allUsers;

  String? _userId;
  String? get userId => _userId;

  void setError(String? error) {
    _error = error;
    notifyListeners();
  }

  void setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  void setUserId(String? id) {
    _userId = id;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    setLoading(true);
    setError(null);
    try {
      final uid = await _userRepo.login(email, password);
      setUserId(uid);
      _user = await _userRepo.getUserId(uid);
      notifyListeners();
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> register(
    String email,
    String password, {
    String name = '',
    String contact = '',
  }) async {
    setLoading(true);
    setError(null);
    try {
      final uid = await _userRepo.register(email, password);
      setUserId(uid);
      final newUser = UserModel(
        id: uid,
        name: name.isEmpty ? email.split('@')[0] : name,
        contact: contact,
        email: email,
        profileImage: 'https://i.pravatar.cc/150?u=$uid',
      );
      await _userRepo.addUser(newUser);
      _user = newUser;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> logout() async {
    setLoading(true);
    setError(null);
    try {
      await _userRepo.logout();
      setUserId(null);
      _user = null;
      _allUsers = null;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> forgetPassword(String email) async {
    setLoading(true);
    setError(null);
    try {
      await _userRepo.forgetPassword(email);
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> addUser(UserModel userModel) async {
    setLoading(true);
    setError(null);
    try {
      await _userRepo.addUser(userModel);
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> deleteUser(String id) async {
    setLoading(true);
    setError(null);
    try {
      await _userRepo.deleteUser(id);
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<void> getAllUser() async {
    setLoading(true);
    setError(null);
    try {
      _allUsers = await _userRepo.getAllUser();
      notifyListeners();
    } on Exception catch (e) {
      setError(e.toString());
    } finally {
      setLoading(false);
    }
  }

  Future<UserModel?> getUserId(String id) async {
    setLoading(true);
    setError(null);
    try {
      final u = await _userRepo.getUserId(id);
      return u;
    } on Exception catch (e) {
      setError(e.toString());
      return null;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> editProfile(UserModel userModel) async {
    setLoading(true);
    setError(null);
    try {
      await _userRepo.editProfile(userModel);
      if (_user?.id == userModel.id) {
        _user = userModel;
      }
      notifyListeners();
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }

  Future<bool> updateProfileImage(String imagePath) async {
    if (_user == null) return false;
    setLoading(true);
    setError(null);
    try {
      final imageUrl = await _userRepo.uploadProfileImage(_user!.id, imagePath);
      final updatedUser = UserModel(
        id: _user!.id,
        name: _user!.name,
        contact: _user!.contact,
        email: _user!.email,
        profileImage: imageUrl,
        aboutMe: _user!.aboutMe,
        fcmToken: _user!.fcmToken,
        isOnline: _user!.isOnline,
        lastSeen: _user!.lastSeen,
      );
      await _userRepo.editProfile(updatedUser);
      _user = updatedUser;
      notifyListeners();
      return true;
    } on Exception catch (e) {
      setError(e.toString());
      return false;
    } finally {
      setLoading(false);
    }
  }
}
