// lib/viewmodel/search_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../repo/user_repo.dart';

class SearchViewModel extends ChangeNotifier {
  final UserRepo _userRepo;

  SearchViewModel(this._userRepo);

  List<UserModel> _userResults = [];
  List<UserModel> get userResults => _userResults;

  bool _isSearching = false;
  bool get isSearching => _isSearching;

  String _query = '';
  String get query => _query;

  Future<void> searchUsers(String query) async {
    _query = query;

    if (query.trim().isEmpty) {
      _userResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    notifyListeners();

    try {
      _userResults = await _userRepo.searchUsers(query);
    } catch (e) {
      _userResults = [];
    }

    _isSearching = false;
    notifyListeners();
  }

  void clearSearch() {
    _query = '';
    _userResults = [];
    notifyListeners();
  }
}
