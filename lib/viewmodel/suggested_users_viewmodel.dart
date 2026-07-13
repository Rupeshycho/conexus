// lib/viewmodel/suggested_users_viewmodel.dart
import 'package:conexus/model/user_model.dart';
import 'package:flutter/foundation.dart';

import '../repo/user_repo.dart';

class SuggestedUsersViewModel extends ChangeNotifier {
  final UserRepo _userRepo;

  SuggestedUsersViewModel(this._userRepo);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  List<UserModel> _suggestedUsers = [];
  List<UserModel> get suggestedUsers => _suggestedUsers;

  Future<void> loadSuggestedUsers(String currentUserId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _suggestedUsers = await _userRepo.getSuggestedUsers(currentUserId);
    } catch (e) {
      _suggestedUsers = [];
    }

    _isLoading = false;
    notifyListeners();
  }
}
