import "package:cloud_firestore/cloud_firestore.dart";

class UserModel {
  final String id;
  final String name;
  final String contact;
  final String email;
  final String profileImage;
  final String aboutMe;
  final String fcmToken;
  final bool isOnline;
  final Timestamp? lastSeen;

  UserModel({
    required this.id,
    required this.name,
    required this.contact,
    required this.email,
    this.profileImage = '',
    this.aboutMe = 'Hey there! I am using Conexus.',
    this.fcmToken = '',
    this.isOnline = true,
    this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'email': email,
      'profileImage': profileImage,
      'aboutMe': aboutMe,
      'fcmToken': fcmToken,
      'isOnline': isOnline,
      'lastSeen': lastSeen ?? FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      contact: map['contact'] as String? ?? '',
      email: map['email'] as String? ?? '',
      profileImage: map['profileImage'] as String? ?? '',
      aboutMe: map['aboutMe'] as String? ?? 'Hey there! I am using Conexus.',
      fcmToken: map['fcmToken'] as String? ?? '',
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: map['lastSeen'] as Timestamp?,
    );
  }
}