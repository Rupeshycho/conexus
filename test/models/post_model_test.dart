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
    });
  });
}
