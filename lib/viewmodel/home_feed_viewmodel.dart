// lib/viewmodel/home_feed_viewmodel.dart
import 'package:flutter/foundation.dart';

import '../models/post_model.dart';
import '../repo/post_repo.dart';

enum FeedStatus { loading, loaded, error }

class HomeFeedViewModel extends ChangeNotifier {
  final PostRepo _postRepo;

  HomeFeedViewModel(this._postRepo) {
    _listenToFeed();
  }

  FeedStatus _status = FeedStatus.loading;
  FeedStatus get status => _status;

  List<PostModel> _posts = [];
  List<PostModel> get posts => _posts;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _listenToFeed() {
    _status = FeedStatus.loading;
    notifyListeners();

    _postRepo.getFeed().listen(
      (posts) {
        _posts = posts;
        _status = FeedStatus.loaded;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = 'Failed to load feed';
        _status = FeedStatus.error;
        notifyListeners();
      },
    );
  }

  Future<void> refreshFeed() async {
    _listenToFeed();
  }
}
