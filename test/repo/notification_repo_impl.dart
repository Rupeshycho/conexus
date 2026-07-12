import 'package:conexus/models/notification_model.dart';
import 'package:conexus/repo/notification_repo_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late NotificationRepoImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = NotificationRepoImpl(firestore: firestore);
  });

  group('NotificationRepoImpl', () {
    test(
      'createNotification writes a document with isRead false by default',
      () async {
        await repo.createNotification(
          type: NotificationType.comment,
          postId: 'p1',
          fromUserId: 'u1',
          fromUsername: 'rupesh',
          fromUserPhotoUrl: ' ',
          toUserId: 'u2',
        );
        final snap = await firestore.collection('notifications').get();
        expect(snap.docs.length, 1);
        expect(snap.docs.first['isRead'], isFalse);
        expect(snap.docs.first['toUserId'], 'u2');
      },
    );
    test(
      'getNotifications only returns notifications for the given user',
      () async {
        await repo.createNotification(
          type: NotificationType.like,
          postId: 'p1',
          fromUserId: 'u1',
          fromUsername: 'a',
          fromUserPhotoUrl: '',
          toUserId: 'u2',
        );
        await repo.createNotification(
          type: NotificationType.like,
          postId: 'p2',
          fromUserId: 'u1',
          fromUsername: 'a',
          fromUserPhotoUrl: '',
          toUserId: 'someone_else',
        );

        final result = await repo.getNotifications('u2').first;

        expect(result.length, 1);
        expect(result.first.toUserId, 'u2');
      },
    );
  });
}
