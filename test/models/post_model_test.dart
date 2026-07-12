import 'package:conexus/models/post_model.dart';
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
  });
}
