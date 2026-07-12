// test/repo/post_repo_impl_test.dart
import 'package:conexus/repo/post_repo_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late PostRepoImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = PostRepoImpl(firestore: firestore);
  });

  group('PostRepoImpl', () {
    test('createTextPost writes a post document with correct fields', () async {
      await repo.createTextPost(
        authorId: 'u1',
        authorUsername: 'rupesh',
        authorPhotoUrl: '',
        caption: 'hello',
      );

      final snap = await firestore.collection('posts').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first['type'], 'text');
      expect(snap.docs.first['caption'], 'hello');
    });

    test('getFeed returns posts ordered by createdAt descending', () async {
      await firestore.collection('posts').add({
        'authorId': 'u1',
        'authorUsername': 'a',
        'authorPhotoUrl': '',
        'type': 'text',
        'caption': 'older',
        'createdAt': DateTime(2026, 1, 1),
        'likeCount': 0,
        'commentCount': 0,
      });
      await firestore.collection('posts').add({
        'authorId': 'u1',
        'authorUsername': 'a',
        'authorPhotoUrl': '',
        'type': 'text',
        'caption': 'newer',
        'createdAt': DateTime(2026, 6, 1),
        'likeCount': 0,
        'commentCount': 0,
      });

      final posts = await repo.getFeed().first;

      expect(posts.length, 2);
      expect(posts.first.caption, 'newer'); // latest first
    });

    test(
      'markNotInterested writes under the user\'s notInterested subcollection',
      () async {
        await repo.markNotInterested('u1', 'post123');

        final snap = await firestore
            .collection('users')
            .doc('u1')
            .collection('notInterested')
            .doc('post123')
            .get();

        expect(snap.exists, isTrue);
      },
    );

    test('reportPost writes a report document with the given reason', () async {
      await repo.reportPost('u1', 'post123', 'spam');

      final snap = await firestore.collection('reports').get();
      expect(snap.docs.length, 1);
      expect(snap.docs.first['reason'], 'spam');
      expect(snap.docs.first['postId'], 'post123');
    });
  });
}
