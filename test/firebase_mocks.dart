import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core_platform_interface/src/pigeon/messages.pigeon.dart';

void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final BasicMessageChannel<Object?> channel = BasicMessageChannel<Object?>(
    'dev.flutter.pigeon.firebase_core_platform_interface.FirebaseCoreHostApi.initializeCore',
    FirebaseCoreHostApi.pigeonChannelCodec,
  );

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler(
    channel,
    (Object? message) async {
      return [
        [
          CoreInitializeResponse(
            name: '[DEFAULT]',
            options: CoreFirebaseOptions(
              apiKey: 'fake-api-key',
              appId: 'fake-app-id',
              messagingSenderId: 'fake-sender-id',
              projectId: 'fake-project-id',
            ),
            pluginConstants: <String?, Object?>{},
          )
        ]
      ];
    },
  );
}
