// test/viewmodel/home_feed_viewmodel_test.dart
import 'dart:async';
import 'dart:io';

import 'package:conexus/models/post_model.dart';
import 'package:conexus/repo/post_repo.dart';
import 'package:conexus/viewmodel/home_feed_viewmodel.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePostRepo implements PostRepo {
  final _controller = StreamController<List<PostModel>>.broadcast();
  bool shouldError = false;

  void emit(List<PostModel> posts) => _controller.add(posts);
  void emitError() => _controller.addError(Exception('feed error'));

  @override
  Stream<List<PostModel>> getFeed() => _controller.stream;

  @override
  Future<void> createTextPost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required String caption,
  }) async {}

  @override
  Future<void> createImagePost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required File file,
    required String caption,
  }) async {}

  @override
  Future<void> createVideoPost({
    required String authorId,
    required String authorUsername,
    required String authorPhotoUrl,
    required File file,
    required String caption,
  }) async {}

  @override
  Future<void> markNotInterested(String userId, String postId) async {}

  @override
  Future<void> reportPost(String userId, String postId, String reason) async {}
}

PostModel _samplePost(String caption) => PostModel(
  postId: '1',
  authorId: 'u1',
  authorUsername: 'rupesh',
  authorPhotoUrl: '',
  type: PostType.text,
  caption: caption,
  createdAt: DateTime.now(),
);

void main() {
  late FakePostRepo fakeRepo;

  setUp(() {
    fakeRepo = FakePostRepo();
  });

  group('HomeFeedViewModel', () {
    test('starts in loading state', () {
      final vm = HomeFeedViewModel(fakeRepo);
      expect(vm.status, FeedStatus.loading);
    });

    test('moves to loaded state with posts when feed emits', () async {
      final vm = HomeFeedViewModel(fakeRepo);
      fakeRepo.emit([_samplePost('hello')]);
      await Future.delayed(Duration.zero); // let the stream event propagate

      expect(vm.status, FeedStatus.loaded);
      expect(vm.posts.length, 1);
      expect(vm.posts.first.caption, 'hello');
    });

    test('moves to error state when feed stream errors', () async {
      final vm = HomeFeedViewModel(fakeRepo);
      fakeRepo.emitError();
      await Future.delayed(Duration.zero);

      expect(vm.status, FeedStatus.error);
      expect(vm.errorMessage, isNotNull);
    });

    test('notifies listeners on state change', () async {
      final vm = HomeFeedViewModel(fakeRepo);
      var notifyCount = 0;
      vm.addListener(() => notifyCount++);

      fakeRepo.emit([_samplePost('x')]);
      await Future.delayed(Duration.zero);

      expect(notifyCount, greaterThan(0));
    });
  });
}
