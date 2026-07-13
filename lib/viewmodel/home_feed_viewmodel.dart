// lib/viewmodel/home_feed_viewmodel.dart
import 'package:conexus/model/post_model.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:flutter/foundation.dart';

enum FeedStatus { loading, loaded, error }

class HomeFeedViewModel extends ChangeNotifier {
  final PostRepo _postRepo;
  final String _viewerId;

  HomeFeedViewModel(this._postRepo, this._viewerId) {
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

    _postRepo
        .getFeed(_viewerId)
        .listen(
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
