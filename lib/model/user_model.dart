class UserModel {
  final String uid;
  final String name;
  final String username;
  final String bio;
  final String profileImage;
  final List<String> followers;
  final List<String> following;

  UserModel({
    required this.uid,
    required this.name,
    required this.username,
    required this.bio,
    required this.profileImage,
    required this.followers,
    required this.following,
  });

  Map<String, dynamic> toMap() {
    return {
      "uid": uid,
      "name": name,
      "username": username,
      "bio": bio,
      "profileImage": profileImage,
      "followers": followers,
      "following": following,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map["uid"] ?? "",
      name: map["name"] ?? "",
      username: map["username"] ?? "",
      bio: map["bio"] ?? "",
      profileImage: map["profileImage"] ?? "",
      followers: List<String>.from(map["followers"] ?? []),
      following: List<String>.from(map["following"] ?? []),
    );
  }
}