import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String username;
  final String bio;
  final String contact;
  final String email;
  final String profileImage;
  final String aboutMe;
  final String fcmToken;
  final bool isOnline;
  final List<String> followers;
  final List<String> following;
  final List<String> blockedUsers;
  final Timestamp? createdAt;
  final Timestamp? lastSeen;

  UserModel({
    required this.id,
    required this.name,
    this.username = '',
    this.bio = '',
    this.contact = '',
    this.email = '',
    this.profileImage = '',
    this.aboutMe = 'Hey there! I am using Conexus.',
    this.fcmToken = '',
    this.isOnline = true,
    this.followers = const [],
    this.following = const [],
    this.blockedUsers = const [],
    this.createdAt,
    this.lastSeen,
  });

  /// Alias for [id] — kept for any call sites still using the older
  /// `uid`-named field from before the merge.
  String get uid => id;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? map['uid'] as String? ?? '',
      name: map['name'] as String? ?? '',
      username: map['username'] as String? ?? '',
      bio: map['bio'] as String? ?? '',
      contact: map['contact'] as String? ?? '',
      email: map['email'] as String? ?? '',
      profileImage: map['profileImage'] as String? ?? '',
      aboutMe: map['aboutMe'] as String? ?? 'Hey there! I am using Conexus.',
      fcmToken: map['fcmToken'] as String? ?? '',
      isOnline: map['isOnline'] as bool? ?? false,
      followers: List<String>.from(map['followers'] ?? []),
      following: List<String>.from(map['following'] ?? []),
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      createdAt: map['createdAt'] as Timestamp?,
      lastSeen: map['lastSeen'] as Timestamp?,
    );
  }

  /// Convenience constructor for building directly off a Firestore
  /// DocumentSnapshot — uses the doc id as the user id so callers don't
  /// have to remember to stuff `id` into the stored document data too.
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      username: data['username'] as String? ?? '',
      bio: data['bio'] as String? ?? '',
      contact: data['contact'] as String? ?? '',
      email: data['email'] as String? ?? '',
      profileImage: data['profileImage'] as String? ?? '',
      aboutMe: data['aboutMe'] as String? ?? 'Hey there! I am using Conexus.',
      fcmToken: data['fcmToken'] as String? ?? '',
      isOnline: data['isOnline'] as bool? ?? false,
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      createdAt: data['createdAt'] as Timestamp?,
      lastSeen: data['lastSeen'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'bio': bio,
      'contact': contact,
      'email': email,
      'profileImage': profileImage,
      'aboutMe': aboutMe,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'followers': followers,
      'following': following,
      'blockedUsers': blockedUsers,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'lastSeen': lastSeen ?? FieldValue.serverTimestamp(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? bio,
    String? contact,
    String? email,
    String? profileImage,
    String? aboutMe,
    String? fcmToken,
    bool? isOnline,
    List<String>? followers,
    List<String>? following,
    List<String>? blockedUsers,
    Timestamp? createdAt,
    Timestamp? lastSeen,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      contact: contact ?? this.contact,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      aboutMe: aboutMe ?? this.aboutMe,
      fcmToken: fcmToken ?? this.fcmToken,
      isOnline: isOnline ?? this.isOnline,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      blockedUsers: blockedUsers ?? this.blockedUsers,
      createdAt: createdAt ?? this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}