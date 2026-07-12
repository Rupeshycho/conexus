import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:conexus/view/forgot_password.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  Future<void> pumpScreen(
      WidgetTester tester, {
        required http.Client httpClient,
        required MockFirebaseAuth firebaseAuth,
      }) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ForgotPasswordScreen(
          httpClient: httpClient,
          firebaseAuth: firebaseAuth,
        ),
      ),
    );
  }

  testWidgets('Shows email field on initial load', (tester) async {
    final mockClient = MockClient((request) async => http.Response('', 200));
    final mockAuth = MockFirebaseAuth();

    await pumpScreen(tester, httpClient: mockClient, firebaseAuth: mockAuth);

    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget);
  });

  testWidgets('Shows error when sending OTP with empty email', (tester) async {
    final mockClient = MockClient((request) async => http.Response('', 200));
    final mockAuth = MockFirebaseAuth();

    await pumpScreen(tester, httpClient: mockClient, firebaseAuth: mockAuth);

    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter your email'), findsOneWidget);
  });

  testWidgets('Successful OTP send moves to OTP entry step', (tester) async {
    final mockClient = MockClient((request) async => http.Response('', 200));
    final mockAuth = MockFirebaseAuth();

    await pumpScreen(tester, httpClient: mockClient, firebaseAuth: mockAuth);

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Enter OTP Code'), findsWidgets);
    expect(find.text('Verify OTP'), findsOneWidget);
  });

  testWidgets('Failed OTP send (non-200) shows error and stays on email step', (tester) async {
    final mockClient = MockClient((request) async => http.Response('error', 500));
    final mockAuth = MockFirebaseAuth();

    await pumpScreen(tester, httpClient: mockClient, firebaseAuth: mockAuth);

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Failed to send OTP. Try again.'), findsOneWidget);
    expect(find.text('Send OTP'), findsOneWidget); // still on step 1
  });

  testWidgets('Wrong OTP shows error and does not advance', (tester) async {
    final mockClient = MockClient((request) async => http.Response('', 200));
    final mockAuth = MockFirebaseAuth();

    await pumpScreen(tester, httpClient: mockClient, firebaseAuth: mockAuth);

    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '000000');
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong OTP. Try again.'), findsOneWidget);
    expect(find.text('Set New Password'), findsNothing);
  });

  testWidgets('Full happy path: email -> OTP -> new password -> success', (tester) async {
    String? capturedOtp;

    final mockClient = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final params = body['template_params'] as Map<String, dynamic>;
      capturedOtp = params['otp_code'] as String;
      return http.Response('', 200);
    });
    final mockAuth = MockFirebaseAuth();

    await pumpScreen(tester, httpClient: mockClient, firebaseAuth: mockAuth);

    // Step 1: send OTP
    await tester.enterText(find.byType(TextField), 'test@example.com');
    await tester.tap(find.text('Send OTP'));
    await tester.pumpAndSettle();

    expect(capturedOtp, isNotNull);

    // Step 2: verify OTP using the OTP the mock client captured
    await tester.enterText(find.byType(TextField).last, capturedOtp!);
    await tester.tap(find.text('Verify OTP'));
    await tester.pumpAndSettle();

    expect(find.text('Set New Password'), findsOneWidget);

    // Step 3: set new password
    final passwordFields = find.byType(TextField);
    await tester.enterText(passwordFields.at(0), 'NewPass123!');
    await tester.enterText(passwordFields.at(1), 'NewPass123!');

    await tester.ensureVisible(find.text('Send Reset Link'));
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();

    // Step 4: success screen
    expect(find.text('Check Your Email'), findsOneWidget);
    expect(find.text('Back to Login'), findsOneWidget);
  });
}
