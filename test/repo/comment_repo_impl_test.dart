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
  });
}
