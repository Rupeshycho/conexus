import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mocks Firebase Core's platform channel so `Firebase.initializeApp()`
/// (and any FlutterFire plugin built on top of it) succeeds in unit/widget
/// tests without a real Firebase backend or platform channel.
///
/// This delegates to `firebase_core_platform_interface`'s own public test
/// helper, `setupFirebaseCoreMocks()`, rather than hand-mocking the
/// pigeon-generated `FirebaseCoreHostApi` channel directly. The classes
/// used to do that (`FirebaseCoreHostApi`, `CoreInitializeResponse`,
/// `CoreFirebaseOptions`, ...) live under `firebase_core_platform_interface
/// /src/pigeon/...` — private implementation details that are regenerated
/// on every package release and can change name or shape without notice.
/// `package:firebase_core_platform_interface/test.dart` is the supported,
/// versioned public entry point the FlutterFire team maintains specifically
/// for this purpose, so it won't drift out of sync with the rest of the
/// package the way a hand-rolled channel mock can.
///
/// Call this once, before `Firebase.initializeApp()`, typically in
/// `setUpAll()`:
///
/// ```dart
/// setUpAll(() {
///   setupFirebaseMocks();
/// });
///
/// test('...', () async {
///   await Firebase.initializeApp();
///   // ...
/// });
/// ```
///
/// If a test needs custom mocked responses (e.g. specific `FirebaseOptions`
/// values), implement `TestFirebaseCoreHostApi` and call
/// `TestFirebaseCoreHostApi.setUp(MyMock())` directly instead of this
/// function — see the `setupFirebaseCoreMocks` docs for details.
void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
}
