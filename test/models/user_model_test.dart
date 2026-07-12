import 'package:conexus/models/user_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserModel', () {
    test('fromFirestore uses document id as uid', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('users').doc('user_123');
      await docRef.set({
        'username': 'rupesh',
        'photoUrl': 'https://example.com/pic.jpg',
        'bio': 'flutter dev',
      });

      final snapshot = await docRef.get();
      final user = UserModel.fromFirestore(snapshot);

      expect(user.uid, 'user_123');
      expect(user.username, 'rupesh');
      expect(user.bio, 'flutter dev');
    });
    test('fromFirestore defaults bio to empty string when missing', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = firestore.collection('users').doc('user_456');
      await docRef.set({'username': 'jack', 'photoUrl': ''});

      final snapshot = await docRef.get();
      final user = UserModel.fromFirestore(snapshot);

      expect(user.bio, '');
    });
  });
}
