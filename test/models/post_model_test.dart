import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/models/post_model.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostModel', () {
    test('toMap contatins correct keys and valuess ', () {
      final post = PostModel(
        postId: '',
        authorId: 'u1',
        authorUsername: 'rupesh',
        authorPhotoUrl: 'https://example.com/pic.jpg',
        type: PostType.image,
        mediaUrl: 'https://res.cloudinary.com/demo/image.jpg',
        caption: 'hello world',
        createdAt: DateTime.now(),
      );
      final map = post.toMap();

      expect(map['authorId'], 'u1');
      expect(map['authorUsername'], 'rupesh');
      expect(map['type'], 'image');
      expect(map['mediaUrl'], 'https://res.cloudinary.com/demo/image.jpg');
      expect(map['caption'], 'hello world');
      expect(map['likeCount'], 0);
      expect(map['commentCount'], 0);
    });
    test('fromFirestore correctly parses a stored document', () async {
      final firestore = FakeFirebaseFirestore();

      final docRef = await firestore.collection('posts').add({
        'authorId': 'u1',
        'authorUsername': 'rupesh',
        'authorPhotoUrl': '',
        'type': 'text',
        'mediaUrl': null,
        'caption': 'test caption',
        'createdAt': Timestamp.now(),
        'likeCount': 5,
        'commentCount': 2,
      });

      final snapshot = await docRef.get();
      final post = PostModel.fromFirestore(snapshot);

      expect(post.postId, docRef.id);
      expect(post.authorUsername, 'rupesh');
      expect(post.type, PostType.text);
      expect(post.caption, 'test caption');
      expect(post.likeCount, 5);
      expect(post.commentCount, 2);
    });
  });
}
