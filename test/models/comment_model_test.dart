import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/models/comment_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CommentModel', () {
    test('toMaq contains correct keys', () {
      final comment = CommentModel(
        commentId: '',
        postId: 'p1',
        authorId: 'u1',
        authorUsername: 'rupesh',
        authorPhotoUrl: '',
        text: 'nice post!',
        createdAt: DateTime.now(),
      );
      final map = comment.toMap();
      expect(map['postId'], 'p1');
      expect(map['authorId'], 'u1');
      expect(map['text'], 'nice Post!');
      expect(map['likedBy'], isEmpty);
    });
    test('fromFirestore parses likedBy list and computes likeCount', () async {
      final firestore = FakeFirebaseFirestore();
      final docRef = await firestore.collection('comments').add({
        'postId': 'p1',
        'authorId': 'u1',
        'authorUsername': 'rupesh',
        'authorPhotoUrl': '',
        'text': 'hello',
        'createdAt': Timestamp.now(),
        'likedBy': ['u2', 'u3'],
      });

      final snapshot = await docRef.get();
      final comment = CommentModel.fromFirestore(snapshot);

      expect(comment.likeCount, 2);
      expect(comment.isLikedBy('u2'), isTrue);
      expect(comment.isLikedBy('u9'), isFalse);
    });
  });
}
