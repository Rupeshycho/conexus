import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:conexus/main.dart';
import 'package:conexus/repo/user_repo_impl.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/viewmodel/theme_view_model.dart';
import 'package:conexus/view/login_screen.dart';

/// Wraps AuthWrapper the same way MyApp's provider tree does, since
/// LoginScreen/MessageFrame may themselves read ThemeViewModel or
/// UserViewModel via context.watch/context.read.
///
/// NOTE: this assumes UserRepoImpl() can be constructed without
/// immediately touching a live Firebase app (e.g. it stores
/// FirebaseFirestore.instance lazily rather than eagerly in its
/// constructor). If UserRepoImpl's constructor itself calls into
/// Firestore/Auth eagerly, this will throw the same kind of
/// `[core/no-app]` error AuthWrapper used to — in that case
/// UserRepoImpl needs the same injectable-fake treatment we gave
/// AgoraService. Share repo/user_repo_impl.dart if that happens.
Widget buildTestableAuthWrapper({required Stream<User?> authStateStream}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeViewModel()),
      ChangeNotifierProvider(
        create: (_) => UserViewModel(userRepo: UserRepoImpl()),
      ),
    ],
    child: MaterialApp(
      home: AuthWrapper(authStateStream: authStateStream),
    ),
  );
}

void main() {
  testWidgets('AuthWrapper shows a loading indicator before the auth stream emits',
          (WidgetTester tester) async {
        // A stream that hasn't emitted yet — StreamBuilder reports
        // ConnectionState.waiting until the first event arrives.
        final controller = StreamController<User?>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          buildTestableAuthWrapper(authStateStream: controller.stream),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
      });

  testWidgets('AuthWrapper shows LoginScreen when signed out (auth stream emits null)',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableAuthWrapper(authStateStream: Stream.value(null)),
        );
        await tester.pump();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Force disposal so LoginScreen's dispose() runs and cancels
        // whatever Timer it's holding, before flutter_test's end-of-test
        // check for pending timers runs.
        await tester.pumpWidget(const SizedBox.shrink());
      });

  // Testing the signed-in branch (MessageFrame) needs a real `User`
  // instance, and hand-implementing FirebaseAuth's User interface is a
  // lot of boilerplate. The standard approach is to add
  // `firebase_auth_mocks` as a dev_dependency and use its `MockUser`:
  //
  //   dev_dependencies:
  //     firebase_auth_mocks: ^0.14.0
  //
  //   testWidgets('AuthWrapper shows MessageFrame when signed in',
  //       (tester) async {
  //     await tester.pumpWidget(
  //       buildTestableAuthWrapper(authStateStream: Stream.value(MockUser())),
  //     );
  //     await tester.pump();
  //     expect(find.byType(MessageFrame), findsOneWidget);
  //   });
  //
  // Left commented out here since it needs that package added first —
  // happy to wire it up once it's in pubspec.yaml.
}
