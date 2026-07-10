import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String username;
  final String email;
  final String photoUrl;
  final String bio;
  final DateTime? createdAt;
  final bool isOnline;
  final DateTime? lastSeen;

  UserModel({
    required this.uid,
    required this.username,
    required this.email,
    this.photoUrl = '',
    this.bio = '',
    this.createdAt,
    this.isOnline = false,
    this.lastSeen,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      bio: data['bio'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      isOnline: data['isOnline'] ?? false,
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username.toLowerCase(),
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'isOnline': isOnline,
      'lastSeen': lastSeen != null ? Timestamp.fromDate(lastSeen!) : null,
    };
  }

  UserModel copyWith({
    String? uid,
    String? username,
    String? email,
    String? photoUrl,
    String? bio,
    DateTime? createdAt,
    bool? isOnline,
    DateTime? lastSeen,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      username: username ?? this.username,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}