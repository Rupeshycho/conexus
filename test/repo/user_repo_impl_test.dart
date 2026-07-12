// test/repo/user_repo_impl_test.dart
import 'package:conexus/repo/user_repo_impl.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late UserRepoImpl repo;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repo = UserRepoImpl(firestore: firestore);
  });

  group('UserRepoImpl', () {
    test('getSuggestedUsers excludes the current user', () async {
      await firestore.collection('users').doc('me').set({
        'username': 'me',
        'photoUrl': '',
        'createdAt': DateTime(2026, 1, 1),
      });
      await firestore.collection('users').doc('other').set({
        'username': 'other',
        'photoUrl': '',
        'createdAt': DateTime(2026, 1, 2),
      });

      final result = await repo.getSuggestedUsers('me');

      expect(result.any((u) => u.uid == 'me'), isFalse);
      expect(result.any((u) => u.uid == 'other'), isTrue);
    });

    test('searchUsers returns an empty list for an empty query', () async {
      final result = await repo.searchUsers('');
      expect(result, isEmpty);
    });

    test('searchUsers finds users by username prefix', () async {
      await firestore.collection('users').doc('u1').set({
        'username': 'rupesh',
        'photoUrl': '',
      });
      await firestore.collection('users').doc('u2').set({
        'username': 'sara',
        'photoUrl': '',
      });

      final result = await repo.searchUsers('rup');

      expect(result.length, 1);
      expect(result.first.username, 'rupesh');
    });
  });
}
