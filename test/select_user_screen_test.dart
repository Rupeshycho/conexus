import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:conexus/view/select_user_screen.dart';
import 'package:conexus/viewmodel/user_view_model.dart';
import 'package:conexus/model/user_model.dart';

class MockUserViewModel extends Mock implements UserViewModel {}

/// SelectUserScreen renders each row's avatar via
/// `CircleAvatar(backgroundImage: NetworkImage(...))`. A bare widget test
/// has no network access, so without faking this every test would try a
/// real HTTP request and print images-decoding exceptions to the console.
///
/// This fakes it directly at the `HttpOverrides` level (no third-party
/// mocking package required): any HTTP request made during a test is
/// answered with the bytes of a valid 1x1 transparent PNG, so
/// `NetworkImage` always resolves successfully.
///
/// IMPORTANT: unlike a hand-rolled byte array, this is the exact,
/// widely-used "smallest valid PNG" byte sequence (the same one the
/// `transparent_image` package ships) — every chunk length and CRC-32
/// below has been checked byte-for-byte against the PNG spec. Flutter's
/// images decoder validates chunk CRCs strictly, so a single mistyped
/// byte here will surface as a codec/decode error at test time that has
/// nothing to do with your widget.
const List<int> _kTransparentPng = <int>[
  // PNG signature
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  // IHDR chunk: length(4) + "IHDR" + data(13) + crc(4)
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00,
  0x1F, 0x15, 0xC4, 0x89,
  // IDAT chunk: length(4) + "IDAT" + data(10) + crc(4)
  0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54,
  0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,
  0x0D, 0x0A, 0x2D, 0xB4,
  // IEND chunk: length(4) + "IEND" + data(0) + crc(4)
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
  // `NetworkImage` reads/writes this property on the shared HttpClient
  // before it ever calls `getUrl`. `Fake`'s default noSuchMethod throws
  // UnimplementedError for anything unstubbed — including property
  // setters/getters — so this must be stubbed as a real no-op field,
  // or every test that renders a NetworkImage fails before the request
  // is even made.
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

  final currentUser = UserModel(
    id: 'current_uid',
    name: 'Current User',
    contact: '',
    email: 'current@example.com',
    profileImage: '',
  );

  final otherUser1 = UserModel(
    id: 'other_uid1',
    name: 'Alice Johnson',
    contact: '',
    email: 'alice@example.com',
    profileImage: '',
  );

  final otherUser2 = UserModel(
    id: 'other_uid2',
    name: 'Bob Miller',
    contact: '',
    email: 'bob@example.com',
    profileImage: '',
  );

  setUp(() {
    mockUserViewModel = MockUserViewModel();
    when(() => mockUserViewModel.userId).thenReturn(currentUser.id);
    when(() => mockUserViewModel.allUsers)
        .thenReturn([currentUser, otherUser1, otherUser2]);
    when(() => mockUserViewModel.loading).thenReturn(false);
    when(() => mockUserViewModel.getAllUser()).thenAnswer((_) async {});
  });

  Widget createSelectUserScreen() {
    return ChangeNotifierProvider<UserViewModel>.value(
      value: mockUserViewModel,
      child: const MaterialApp(
        home: SelectUserScreen(),
      ),
    );
  }

  group('SelectUserScreen', () {
    testWidgets('renders other users and excludes the current user',
            (tester) async {
          await tester.pumpWidget(createSelectUserScreen());
          await tester.pump();

          // getAllUser() is fired from a post-frame callback in initState.
          verify(() => mockUserViewModel.getAllUser()).called(1);

          expect(find.text('Alice Johnson'), findsOneWidget);
          expect(find.text('Bob Miller'), findsOneWidget);
          expect(find.text('Current User'), findsNothing);
        });

    testWidgets('shows a loading indicator only while allUsers is still null',
            (tester) async {
          when(() => mockUserViewModel.allUsers).thenReturn(null);
          when(() => mockUserViewModel.loading).thenReturn(true);

          await tester.pumpWidget(createSelectUserScreen());
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('Alice Johnson'), findsNothing);
          expect(find.text('No users found'), findsNothing);
        });

    testWidgets('filters the list by name, case-insensitively', (tester) async {
      await tester.pumpWidget(createSelectUserScreen());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'ALICE');
      await tester.pump();

      expect(find.text('Alice Johnson'), findsOneWidget);
      expect(find.text('Bob Miller'), findsNothing);
    });

    testWidgets('filters the list by email as well as name', (tester) async {
      await tester.pumpWidget(createSelectUserScreen());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'bob@example');
      await tester.pump();

      expect(find.text('Bob Miller'), findsOneWidget);
      expect(find.text('Alice Johnson'), findsNothing);
    });

    testWidgets('never shows the current user, even if the search text matches them',
            (tester) async {
          await tester.pumpWidget(createSelectUserScreen());
          await tester.pump();

          await tester.enterText(find.byType(TextField), 'Current');
          await tester.pump();

          expect(find.text('Current User'), findsNothing);
          expect(find.text('No users found'), findsOneWidget);
        });

    testWidgets('shows "No users found" when the search matches nobody',
            (tester) async {
          await tester.pumpWidget(createSelectUserScreen());
          await tester.pump();

          await tester.enterText(find.byType(TextField), 'zzz-nobody-zzz');
          await tester.pump();

          expect(find.text('No users found'), findsOneWidget);
        });

    testWidgets('the clear button resets the search and restores the full list',
            (tester) async {
          await tester.pumpWidget(createSelectUserScreen());
          await tester.pump();

          // No clear button until there's text to clear.
          expect(find.byIcon(Icons.close), findsNothing);

          await tester.enterText(find.byType(TextField), 'Alice');
          await tester.pump();
          expect(find.text('Bob Miller'), findsNothing);
          expect(find.byIcon(Icons.close), findsOneWidget);

          await tester.tap(find.byIcon(Icons.close));
          await tester.pump();

          expect(find.text('Alice Johnson'), findsOneWidget);
          expect(find.text('Bob Miller'), findsOneWidget);
          expect(find.byIcon(Icons.close), findsNothing);
        });

    testWidgets('the back button pops the screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider<UserViewModel>.value(
                        value: mockUserViewModel,
                        child: const SelectUserScreen(),
                      ),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectUserScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_ios));
      await tester.pumpAndSettle();

      expect(find.byType(SelectUserScreen), findsNothing);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}