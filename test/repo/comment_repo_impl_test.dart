import 'package:conexus/models/notification_model.dart';
import 'package:conexus/repo/comment_repo_impl.dart';
import 'package:conexus/repo/notification_repo.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeNotificationRepo implements NotificationRepo {
  final List<Map<String, dynamic>> createdNotifications = [];

  @override
  Future<void> createNotification({
    required NotificationType type,
    required String postId,
    required String fromUserId,
    required String fromUsername,
    required String fromUserPhotoUrl,
    required String toUserId,
  }) async {
    createdNotifications.add({
      'type': type,
      'postId': postId,
      'fromUserId': fromUserId,
      'toUserId': toUserId,
    });
  }

  @override
  Stream<List<NotificationModel>> getNotifications(String userId) =>
      const Stream.empty();

  @override
  Future<void> markAsRead(String notificationId) async {}
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeNotificationRepo fakeNotificationRepo;
  late CommentRepoImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    fakeNotificationRepo = FakeNotificationRepo();
    repo = CommentRepoImpl(
      notificationRepo: fakeNotificationRepo,
      firestore: firestore,
    );
  });
  group('CommentRepoImpl', () {
    test(
      'addComment saves the comment and increaments post commnetCount',
      () async {
        final postRef = await firestore.collection('posts').add({
          'authorId': 'owner1',
          'commentCount': 0,
        });
        await repo.addComment(
          postId: postRef.id,
          authorId: 'commenter1',
          authorUsername: 'jack',
          authorPhotoUrl: '',
          text: 'nice!',
        );
        final comments = await firestore.collection('comments').get();
        expect(comments.docs.length, 1);
        expect(comments.docs.first['text'], 'nice!');

        final postSnap = await postRef.get();
        expect(postSnap['commentCount'], 1);
      },
    );
    test(
      'addComment triggers a notification when commenting on someone else\'s post',
      () async {
        final postRef = await firestore.collection('posts').add({
          'authorId': 'owner1',
          'commentCount': 0,
        });

        await repo.addComment(
          postId: postRef.id,
          authorId: 'commenter1',
          authorUsername: 'jack',
          authorPhotoUrl: '',
          text: 'nice!',
        );

        expect(fakeNotificationRepo.createdNotifications.length, 1);
        expect(
          fakeNotificationRepo.createdNotifications.first['toUserId'],
          'owner1',
        );
      },
    );
    test(
      'addComment does NOT notify when commenting on your own post',
      () async {
        final postRef = await firestore.collection('posts').add({
          'authorId': 'owner1',
          'commentCount': 0,
        });

        await repo.addComment(
          postId: postRef.id,
          authorId: 'owner1', // same as post author
          authorUsername: 'owner1',
          authorPhotoUrl: '',
          text: 'my own comment',
        );

        expect(fakeNotificationRepo.createdNotifications, isEmpty);
      },
    );
    test('toggleLikeComment adds then removes a like correctly', () async {
      final commentRef = await firestore.collection('comments').add({
        'postId': 'p1',
        'authorId': 'a',
        'likedBy': [],
      });

      await repo.toggleLikeComment(commentRef.id, 'u2');
      var snap = await commentRef.get();
      expect(List<String>.from(snap['likedBy']), contains('u2'));

      await repo.toggleLikeComment(commentRef.id, 'u2'); // toggle off
      snap = await commentRef.get();
      expect(List<String>.from(snap['likedBy']), isNot(contains('u2')));
    });
    test(
      'deleteComment removes the comment and decrements commentCount',
      () async {
        final postRef = await firestore.collection('posts').add({
          'authorId': 'owner1',
          'commentCount': 1,
        });
        final commentRef = await firestore.collection('comments').add({
          'postId': postRef.id,
          'authorId': 'commenter1',
          'text': 'delete me',
        });

        await repo.deleteComment(commentRef.id, 'commenter1');

        final snap = await commentRef.get();
        expect(snap.exists, isFalse);

        final postSnap = await postRef.get();
        expect(postSnap['commentCount'], 0);
      },
    );
    test(
      'deleteComment throws if a different user tries to delete it',
      () async {
        final commentRef = await firestore.collection('comments').add({
          'postId': 'p1',
          'authorId': 'commenter1',
          'text': 'not yours',
        });

        expect(
          () => repo.deleteComment(commentRef.id, 'someone_else'),
          throwsException,
        );
      },
    );
  });
}
