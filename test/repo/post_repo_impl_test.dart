import 'package:conexus/repo/post_repo_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  repo = PostRepoImpl(firestore: firestore);

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
  });
}
