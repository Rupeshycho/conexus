import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:conexus/view/profile_screen.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/model/user_model.dart';

class MockUserViewModel extends Mock implements UserViewModel {}

/// Same fake used by SelectUserScreen's tests: NetworkImage needs a working
/// HttpClient or it throws during paint. Only exercised here by the test
/// that gives the user a non-empty `profileImage`, but it's registered
/// globally so any future test that adds a network avatar is covered too.
const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00,
  0x1F, 0x15, 0xC4, 0x89,
  0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4,
  0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
  0xAE, 0x42, 0x60, 0x82,
];

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  _FakeHttpClientResponse(this._bytes);
  final List<int> _bytes;

  @override
  int get statusCode => 200;

  @override
  int get contentLength => _bytes.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
      void Function(List<int> event)? onData, {
        Function? onError,
        void Function()? onDone,
        bool? cancelOnError,
      }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_bytes]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  set followRedirects(bool value) {}

  @override
  set maxRedirects(int value) {}

  @override
  set persistentConnection(bool value) {}

  @override
  Future<HttpClientResponse> close() async =>
      _FakeHttpClientResponse(_kTransparentPng);
}

class _FakeHttpClient extends Fake implements HttpClient {
  // Must be a real stubbed property, not left to Fake's noSuchMethod, or
  // NetworkImage throws UnimplementedError before it ever calls getUrl.
  bool _autoUncompress = true;

  @override
  bool get autoUncompress => _autoUncompress;

  @override
  set autoUncompress(bool value) => _autoUncompress = value;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
}

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  tearDownAll(() {
    HttpOverrides.global = null;
  });

  late MockUserViewModel mockUserViewModel;

  final tUserModel = UserModel(
    id: 'uid123',
    name: 'Jane Doe',
    contact: '9876543210',
    email: 'jane@example.com',
    profileImage: '',
    aboutMe: 'Software Engineer',
  );

  final tUserModelWithImage = UserModel(
    id: 'uid123',
    name: 'Jane Doe',
    contact: '9876543210',
    email: 'jane@example.com',
    profileImage: 'https://example.com/avatar.png',
    aboutMe: 'Software Engineer',
  );

  setUpAll(() {
    registerFallbackValue(tUserModel);
  });

  setUp(() {
    mockUserViewModel = MockUserViewModel();
    when(() => mockUserViewModel.user).thenReturn(tUserModel);
    when(() => mockUserViewModel.loading).thenReturn(false);
    when(() => mockUserViewModel.error).thenReturn(null);
    when(() => mockUserViewModel.editProfile(any()))
        .thenAnswer((_) async => true);
    when(() => mockUserViewModel.updateProfileImage(any()))
        .thenAnswer((_) async => true);
  });

  Widget createProfileScreen() {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: mockUserViewModel,
      child: const MaterialApp(
        home: ProfileScreen(),
      ),
    );
  }

  /// `_saveProfile` calls `Navigator.pop(context)` on success, so any test
  /// that exercises a successful save needs somewhere to pop back to.
  /// Mounting ProfileScreen as the app's only route (as the original test
  /// did) means that pop has no route beneath it once it returns.
  Widget createProfileScreenWithNavigator() {
    return MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider<UserViewModel>.value(
                    value: mockUserViewModel,
                    child: const ProfileScreen(),
                  ),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
  }

  group('ProfileScreen', () {
    testWidgets('renders the user\'s current name and about-me text',
            (tester) async {
          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          expect(find.widgetWithText(TextField, 'Display Name'), findsOneWidget);
          expect(find.widgetWithText(TextField, 'About Me'), findsOneWidget);
          expect(find.text('Jane Doe'), findsOneWidget);
          expect(find.text('Software Engineer'), findsOneWidget);
        });

    testWidgets('shows "No User Found" and no form when there is no user',
            (tester) async {
          when(() => mockUserViewModel.user).thenReturn(null);

          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          expect(find.text('No User Found'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          expect(find.byType(ElevatedButton), findsNothing);
        });

    testWidgets('shows a placeholder icon when the user has no profile images',
            (tester) async {
          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          // Icons.person also appears as the "Display Name" field's
          // prefixIcon, so byIcon() alone is ambiguous here — scope the
          // check to the avatar's own child instead.
          final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
          expect(avatar.backgroundImage, isNull);
          expect(avatar.child, isA<Icon>());
          expect((avatar.child as Icon).icon, Icons.person);

          expect(
            find.descendant(
              of: find.byType(CircleAvatar),
              matching: find.byIcon(Icons.person),
            ),
            findsOneWidget,
          );
        });

    testWidgets('renders a network images avatar when the user has one',
            (tester) async {
          when(() => mockUserViewModel.user).thenReturn(tUserModelWithImage);

          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
          expect(avatar.backgroundImage, isA<NetworkImage>());
          // No fallback icon once there's an images to show.
          expect(avatar.child, isNull);
          expect(
            find.descendant(
              of: find.byType(CircleAvatar),
              matching: find.byIcon(Icons.person),
            ),
            findsNothing,
          );
          expect(
            (avatar.backgroundImage as NetworkImage).url,
            'https://example.com/avatar.png',
          );
        });

    testWidgets(
        'disables Save and shows a spinner instead of the label while loading',
            (tester) async {
          when(() => mockUserViewModel.loading).thenReturn(true);

          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          final button = tester.widget<ElevatedButton>(
            find.byType(ElevatedButton),
          );
          expect(button.onPressed, isNull);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('Save Changes'), findsNothing);
        });

    testWidgets(
        'shows a validation message and never calls editProfile when the name is cleared',
            (tester) async {
          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          await tester.enterText(
            find.widgetWithText(TextField, 'Display Name'),
            '',
          );
          await tester.tap(find.text('Save Changes'));
          await tester.pumpAndSettle();

          expect(find.text('Name cannot be empty'), findsOneWidget);
          verifyNever(() => mockUserViewModel.editProfile(any()));
        });

    testWidgets('saves the edited name and pops the screen on success',
            (tester) async {
          await tester.pumpWidget(createProfileScreenWithNavigator());

          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          expect(find.byType(ProfileScreen), findsOneWidget);

          await tester.enterText(
            find.widgetWithText(TextField, 'Display Name'),
            'Jane Roe',
          );
          await tester.tap(find.text('Save Changes'));
          await tester.pumpAndSettle();

          final captured =
              verify(() => mockUserViewModel.editProfile(captureAny()))
                  .captured;
          expect(captured, hasLength(1));
          expect((captured.single as UserModel).name, 'Jane Roe');

          // Screen popped back to the caller.
          expect(find.byType(ProfileScreen), findsNothing);
          expect(find.text('Open'), findsOneWidget);
        });

    testWidgets(
        'shows the view model\'s error message and stays on screen when saving fails',
            (tester) async {
          when(() => mockUserViewModel.editProfile(any()))
              .thenAnswer((_) async => false);
          when(() => mockUserViewModel.error).thenReturn('Update failed');

          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          await tester.tap(find.text('Save Changes'));
          await tester.pumpAndSettle();

          expect(find.text('Update failed'), findsOneWidget);
          expect(find.byType(ProfileScreen), findsOneWidget);
        });

    testWidgets(
        'falls back to a generic error message when the view model has none',
            (tester) async {
          when(() => mockUserViewModel.editProfile(any()))
              .thenAnswer((_) async => false);
          when(() => mockUserViewModel.error).thenReturn(null);

          await tester.pumpWidget(createProfileScreen());
          await tester.pump();

          await tester.tap(find.text('Save Changes'));
          await tester.pumpAndSettle();

          expect(find.text('Failed to update profile'), findsOneWidget);
        });
  });
}
