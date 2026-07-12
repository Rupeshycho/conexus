import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',

        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
<<<<<<< HEAD
          'you can reconfigure this by running the FlutterFire CLI again.',
=======
              'you can reconfigure this by running the FlutterFire CLI again.',

>>>>>>> development
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
<<<<<<< HEAD
=======
<<<<<<< HEAD
>>>>>>> development
    apiKey: 'AIzaSyA8Zg8POGkVJuOsJY2_JPmqw2Y6yX-Dy5Y',
    appId: '1:1069485922735:web:9f6b9d841a77a85f27375a',
    messagingSenderId: '1069485922735',
    projectId: 'conexus-b9d4b',
    authDomain: 'conexus-b9d4b.firebaseapp.com',
    storageBucket: 'conexus-b9d4b.firebasestorage.app',
    measurementId: 'G-N5QMXN6T63',
<<<<<<< HEAD
=======
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCHfSgfZcRLLIjw8SiD6cHdeerYe81u5tE',
    appId: '1:1069485922735:android:6476f78bd15adb3427375a',
    messagingSenderId: '1069485922735',
    projectId: 'conexus-b9d4b',
    storageBucket: 'conexus-b9d4b.firebasestorage.app',
  );




=======
    apiKey: 'AIzaSyAMjx5UHJCusjhg_vp-yinLIbEddNncXQs',
    appId: '1:557686259128:web:1ff263ce2bab0faa71234d',
    messagingSenderId: '557686259128',
    projectId: 'group-project-df1b3',
    authDomain: 'group-project-df1b3.firebaseapp.com',
    storageBucket: 'group-project-df1b3.firebasestorage.app',
    measurementId: 'G-281V37Q5TD',
>>>>>>> development
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCHfSgfZcRLLIjw8SiD6cHdeerYe81u5tE',
    appId: '1:1069485922735:android:c6015a0af7265a4627375a',
    messagingSenderId: '1069485922735',
    projectId: 'conexus-b9d4b',
    storageBucket: 'conexus-b9d4b.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDcgfPFiIIfePlfE-OoPu1kqo5qfs6tsxM',
    appId: '1:1069485922735:ios:386c24c63085a61d27375a',
    messagingSenderId: '1069485922735',
    projectId: 'conexus-b9d4b',
    storageBucket: 'conexus-b9d4b.firebasestorage.app',
    iosClientId: '1069485922735-oel5guuvvse9ut3sncl7fg0lduna8msn.apps.googleusercontent.com',
    iosBundleId: 'com.example.groupProject',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDcgfPFiIIfePlfE-OoPu1kqo5qfs6tsxM',
    appId: '1:1069485922735:ios:386c24c63085a61d27375a',
    messagingSenderId: '1069485922735',
    projectId: 'conexus-b9d4b',
    storageBucket: 'conexus-b9d4b.firebasestorage.app',
    iosClientId: '1069485922735-oel5guuvvse9ut3sncl7fg0lduna8msn.apps.googleusercontent.com',
    iosBundleId: 'com.example.groupProject',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyA8Zg8POGkVJuOsJY2_JPmqw2Y6yX-Dy5Y',
    appId: '1:1069485922735:web:ec6cc74c409da33227375a',
    messagingSenderId: '1069485922735',
    projectId: 'conexus-b9d4b',
    authDomain: 'conexus-b9d4b.firebaseapp.com',
    storageBucket: 'conexus-b9d4b.firebasestorage.app',
    measurementId: 'G-S8QM4804R2',
  );
}
