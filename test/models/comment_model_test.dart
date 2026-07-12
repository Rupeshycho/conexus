import 'package:conexus/models/comment_model.dart';
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
  });
}
