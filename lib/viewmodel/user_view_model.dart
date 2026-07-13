import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  // Alias so screens that expect `currentUser` (e.g. ProfileScreen) share
  // the same underlying state as `.user`, rather than a second copy.
  UserModel? get currentUser => _user;

  List<UserModel>? _allUsers;
  List<UserModel>? get allUsers => _allUsers;

  String? _userId;
  String? get userId => _userId;

  // NEW: search state for SearchScreen.
  List<UserModel> _searchResults = [];
  List<UserModel> get searchResults => _searchResults;

  bool _searching = false;
  bool get searching => _searching;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

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

  // Keeps `_user` in sync with Firestore in real time. Restarted any time
  // a new user is established (login/register/loadCurrentUser).
  void _listenToUserChanges(String uid) {
    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (snapshot) {
        final data = snapshot.data();
        if (snapshot.exists && data != null) {
          _user = UserModel.fromMap(data);
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("❌ Real-time user listener error: $error");
      },
    );
  }

  Future<bool> login(String email, String password) async {
    setLoading(true);
    setError(null);
    try {
      final uid = await _userRepo.login(email, password);
      setUserId(uid);
      _user = await _userRepo.getUserId(uid);
      _listenToUserChanges(uid);
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
      _listenToUserChanges(uid);
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
      await _userSubscription?.cancel();
      _userSubscription = null;
      setUserId(null);
      _user = null;
      _allUsers = null;
      _searchResults = [];
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

  Future<void> loadCurrentUser() async {
    setLoading(true);
    setError(null);
    try {
      _user = await _userRepo.getCurrentUser();
      if (_user != null) {
        setUserId(_user!.id);
        _listenToUserChanges(_user!.id);
      }
      notifyListeners();
    } on Exception catch (e) {
      setError(e.toString());
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
      final updatedUser = _user!.copyWith(profileImage: imageUrl);
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

  // NEW: real user search for SearchScreen, backed by
  // UserRepo.searchUsers (prefix match on `name`).
  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _searching = true;
    notifyListeners();
    try {
      _searchResults = await _userRepo.searchUsers(query.trim());
    } on Exception catch (e) {
      setError(e.toString());
      _searchResults = [];
    } finally {
      _searching = false;
      notifyListeners();
    }
  }

  // ── Profile lookup / social ──

  Future<UserModel> getUser(String uid) async {
    return _userRepo.getUserById(uid);
  }

  Future<void> follow(String uid) async {
    try {
      await _userRepo.followUser(uid);
      if (_user != null && !_user!.following.contains(uid)) {
        _user = _user!.copyWith(following: [..._user!.following, uid]);
        notifyListeners();
      }
    } on Exception catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> unfollow(String uid) async {
    try {
      await _userRepo.unfollowUser(uid);
      if (_user != null && _user!.following.contains(uid)) {
        _user = _user!.copyWith(
          following: _user!.following.where((id) => id != uid).toList(),
        );
        notifyListeners();
      }
    } on Exception catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  bool isFollowing(String uid) {
    if (_user == null) return false;
    return _user!.following.contains(uid);
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
  Future<void> block(String uid) async {
    try {
      await _userRepo.blockUser(uid);
      if (_user != null) {
        final updatedBlocked = _user!.blockedUsers.contains(uid)
            ? _user!.blockedUsers
            : [..._user!.blockedUsers, uid];
        _user = _user!.copyWith(
          blockedUsers: updatedBlocked,
          following: _user!.following.where((id) => id != uid).toList(),
          followers: _user!.followers.where((id) => id != uid).toList(),
        );
        notifyListeners();
      }
    } on Exception catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  Future<void> unblock(String uid) async {
    try {
      await _userRepo.unblockUser(uid);
      if (_user != null && _user!.blockedUsers.contains(uid)) {
        _user = _user!.copyWith(
          blockedUsers: _user!.blockedUsers.where((id) => id != uid).toList(),
        );
        notifyListeners();
      }
    } on Exception catch (e) {
      setError(e.toString());
      rethrow;
    }
  }

  bool isBlocked(String uid) {
    if (_user == null) return false;
    return _user!.blockedUsers.contains(uid);
  }
}