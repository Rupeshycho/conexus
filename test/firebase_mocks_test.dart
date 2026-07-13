import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/firebase_mocks.dart';

void main() {
  setUpAll(() {
    setupFirebaseMocks();
  });

  test('setupFirebaseMocks lets Firebase.initializeApp() succeed offline',
          () async {
        final app = await Firebase.initializeApp();

        // Firebase.app() resolving without throwing "No Firebase App has been
        // created" — and reporting the same app name — proves initialization
        // actually completed against the mock, not just that the call didn't
        // crash. (FirebaseApp wrappers aren't cached as singletons, so we
        // compare by name/value rather than object identity.)
        expect(Firebase.app().name, app.name);
        expect(Firebase.apps, hasLength(1));

        expect(app.options.apiKey, isNotEmpty);
        expect(app.options.appId, isNotEmpty);
        expect(app.options.projectId, isNotEmpty);
        expect(app.options.messagingSenderId, isNotEmpty);
      });
}
