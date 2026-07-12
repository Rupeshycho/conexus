import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

import 'package:conexus/services/auth_service.dart';
import 'package:conexus/view/login_screen.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('Login screen shows email and password fields', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockAuth = MockFirebaseAuth();
    final authService = AuthService(firebaseAuth: mockAuth);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: authService),
      ),
    );

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Shows error snackbar when fields are empty', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockAuth = MockFirebaseAuth();
    final authService = AuthService(firebaseAuth: mockAuth);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: authService),
      ),
    );

    await tester.ensureVisible(find.text('Login'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Login'));
    await tester.pump(); // let the SnackBar animate in

    expect(find.text('Please enter email and password'), findsOneWidget);
  });

  testWidgets('Successful login navigates away from LoginScreen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockUser = MockUser(
      isEmailVerified: true,
      uid: 'test-uid',
      email: 'test@example.com',
    );
    final mockAuth = MockFirebaseAuth(mockUser: mockUser, signedIn: false);
    final authService = AuthService(firebaseAuth: mockAuth);

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authService: authService),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');

    await tester.ensureVisible(find.text('Login'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Login'));
    await tester.pumpAndSettle();

    // LoginScreen navigates to SignupScreen on success in your current code —
    // adjust this expectation once that's pointed at your real home screen.
    expect(find.byType(LoginScreen), findsNothing);
  });
}