// Unit tests for UserModel (lib/model/user_model.dart — adjust the import
// below to match its actual path in your project).
//
// No Firebase initialization is required for these tests: `Timestamp` is a
// plain value object with no platform-channel calls, so this file runs as
// a pure `dart test` / `flutter test` unit test with zero mocking.

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conexus/model/user_model.dart'; // adjust to actual path

void main() {
  group('UserModel constructor defaults', () {
    test('applies default aboutMe, fcmToken, isOnline, profileImage when omitted', () {
      final user = UserModel(
        id: 'u1',
        name: 'Jane Doe',
        contact: '9800000000',
        email: 'jane@example.com',
      );

      expect(user.profileImage, '');
      expect(user.aboutMe, 'Hey there! I am using Conexus.');
      expect(user.fcmToken, '');
      expect(user.isOnline, isTrue);
      expect(user.lastSeen, isNull);
    });

    test('keeps explicitly provided values instead of defaults', () {
      final seen = Timestamp.fromDate(DateTime(2026, 1, 1));
      final user = UserModel(
        id: 'u2',
        name: 'John Roe',
        contact: '9811111111',
        email: 'john@example.com',
        profileImage: 'https://example.com/pic.png',
        aboutMe: 'Custom bio',
        fcmToken: 'token-abc',
        isOnline: false,
        lastSeen: seen,
      );

      expect(user.profileImage, 'https://example.com/pic.png');
      expect(user.aboutMe, 'Custom bio');
      expect(user.fcmToken, 'token-abc');
      expect(user.isOnline, isFalse);
      expect(user.lastSeen, seen);
    });
  });

  group('UserModel.toMap', () {
    test('includes all fields with the correct keys', () {
      final seen = Timestamp.fromDate(DateTime(2026, 1, 1));
      final user = UserModel(
        id: 'u1',
        name: 'Jane Doe',
        contact: '9800000000',
        email: 'jane@example.com',
        profileImage: 'pic.png',
        aboutMe: 'Bio',
        fcmToken: 'tok',
        isOnline: true,
        lastSeen: seen,
      );

      final map = user.toMap();

      expect(map['id'], 'u1');
      expect(map['name'], 'Jane Doe');
      expect(map['contact'], '9800000000');
      expect(map['email'], 'jane@example.com');
      expect(map['profileImage'], 'pic.png');
      expect(map['aboutMe'], 'Bio');
      expect(map['fcmToken'], 'tok');
      expect(map['isOnline'], isTrue);
      expect(map['lastSeen'], seen);
    });

    test('falls back to FieldValue.serverTimestamp() when lastSeen is null', () {
      final user = UserModel(
        id: 'u1',
        name: 'Jane Doe',
        contact: '9800000000',
        email: 'jane@example.com',
      );

      final map = user.toMap();

      expect(map['lastSeen'], isA<FieldValue>());
    });
  });

  group('UserModel.fromMap', () {
    test('parses a fully populated map', () {
      final seen = Timestamp.fromDate(DateTime(2026, 1, 1));
      final map = {
        'id': 'u1',
        'name': 'Jane Doe',
        'contact': '9800000000',
        'email': 'jane@example.com',
        'profileImage': 'pic.png',
        'aboutMe': 'Bio',
        'fcmToken': 'tok',
        'isOnline': true,
        'lastSeen': seen,
      };

      final user = UserModel.fromMap(map);

      expect(user.id, 'u1');
      expect(user.name, 'Jane Doe');
      expect(user.contact, '9800000000');
      expect(user.email, 'jane@example.com');
      expect(user.profileImage, 'pic.png');
      expect(user.aboutMe, 'Bio');
      expect(user.fcmToken, 'tok');
      expect(user.isOnline, isTrue);
      expect(user.lastSeen, seen);
    });

    test('defaults every field safely when given an empty map', () {
      final user = UserModel.fromMap(<String, dynamic>{});

      expect(user.id, '');
      expect(user.name, '');
      expect(user.contact, '');
      expect(user.email, '');
      expect(user.profileImage, '');
      expect(user.aboutMe, 'Hey there! I am using Conexus.');
      expect(user.fcmToken, '');
      expect(user.lastSeen, isNull);
    });

    test('defaults isOnline to false when missing (differs from the constructor default of true)', () {
      // This documents an existing asymmetry in UserModel: the bare
      // constructor defaults isOnline to true, but fromMap defaults it to
      // false when the key is absent. If that's unintentional, this test
      // will flag it the moment someone "fixes" one side without the other.
      final user = UserModel.fromMap({'id': 'u1'});
      expect(user.isOnline, isFalse);
    });

    test('ignores unknown extra keys without throwing', () {
      final map = {
        'id': 'u1',
        'name': 'Jane',
        'contact': '123',
        'email': 'jane@example.com',
        'unexpectedField': 'should be ignored',
      };

      expect(() => UserModel.fromMap(map), returnsNormally);
    });
  });

  group('round trip', () {
    test('toMap -> fromMap preserves all non-server-timestamp fields', () {
      final seen = Timestamp.fromDate(DateTime(2026, 3, 15, 10, 30));
      final original = UserModel(
        id: 'u1',
        name: 'Jane Doe',
        contact: '9800000000',
        email: 'jane@example.com',
        profileImage: 'pic.png',
        aboutMe: 'Bio',
        fcmToken: 'tok',
        isOnline: true,
        lastSeen: seen,
      );

      final roundTripped = UserModel.fromMap(original.toMap());

      expect(roundTripped.id, original.id);
      expect(roundTripped.name, original.name);
      expect(roundTripped.contact, original.contact);
      expect(roundTripped.email, original.email);
      expect(roundTripped.profileImage, original.profileImage);
      expect(roundTripped.aboutMe, original.aboutMe);
      expect(roundTripped.fcmToken, original.fcmToken);
      expect(roundTripped.isOnline, original.isOnline);
      expect(roundTripped.lastSeen, original.lastSeen);
    });
  });
}
