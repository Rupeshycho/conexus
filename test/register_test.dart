import 'package:conexus/view/register.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:conexus/view/register.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpScreen(
      WidgetTester tester, {
        required MockFirebaseAuth firebaseAuth,
        required FakeFirebaseFirestore firestore,
      }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home:SignupScreen(
          firebaseAuth: firebaseAuth,
          firestore: firestore,
        ),
      ),
    );
  }

  testWidgets('Shows all fields on initial load', (tester) async {
    await pumpScreen(
      tester,
      firebaseAuth: MockFirebaseAuth(),
      firestore: FakeFirebaseFirestore(),
    );

    expect(find.text('Create Your Account'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('Sign Up →'), findsOneWidget);
  });

  testWidgets('Mismatched passwords shows error', (tester) async {
    await pumpScreen(
      tester,
      firebaseAuth: MockFirebaseAuth(),
      firestore: FakeFirebaseFirestore(),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), 'testuser');
    await tester.enterText(fields.at(2), 'Password123!');
    await tester.enterText(fields.at(3), 'Different123!');

    await tester.ensureVisible(find.text('Sign Up →'));
    await tester.tap(find.text('Sign Up →'));
    await tester.pump();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('Unchecked terms shows error', (tester) async {
    await pumpScreen(
      tester,
      firebaseAuth: MockFirebaseAuth(),
      firestore: FakeFirebaseFirestore(),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'test@example.com');
    await tester.enterText(fields.at(1), 'testuser');
    await tester.enterText(fields.at(2), 'Password123!');
    await tester.enterText(fields.at(3), 'Password123!');

    // Checkbox left unchecked (isChecked defaults to false)
    await tester.ensureVisible(find.text('Sign Up →'));
    await tester.tap(find.text('Sign Up →'));
    await tester.pump();

    expect(find.text('Please accept Terms & Conditions'), findsOneWidget);
  });

  testWidgets('Successful signup writes user doc and shows success message',
          (tester) async {
        final firestore = FakeFirebaseFirestore();
        final auth = MockFirebaseAuth();

        await pumpScreen(tester, firebaseAuth: auth, firestore: firestore);

        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'test@example.com');
        await tester.enterText(fields.at(1), 'testuser');
        await tester.enterText(fields.at(2), 'Password123!');
        await tester.enterText(fields.at(3), 'Password123!');

        await tester.tap(find.byType(Checkbox));
        await tester.pump();

        await tester.ensureVisible(find.text('Sign Up →'));
        await tester.tap(find.text('Sign Up →'));
        await tester.pump(); // let the createUser + firestore.set() futures resolve

        expect(find.text('Signup Successful'), findsOneWidget);

        final snapshot = await firestore.collection('users').get();
        expect(snapshot.docs.length, 1);
        expect(snapshot.docs.first.data()['email'], 'test@example.com');
        expect(snapshot.docs.first.data()['username'], 'testuser');
      });
}