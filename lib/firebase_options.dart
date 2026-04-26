import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase options con valores hardcodeados del proyecto.
/// Estos valores son públicos por diseño (Google lo documenta así).
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC_1ZheE4ZtZJZS_qJXdt2Lp0m-gJ0sVJM',
    appId: '1:722933984234:web:21cf4c97d418c88a68a093',
    messagingSenderId: '722933984234',
    projectId: 'workflows-fc6cd',
    authDomain: 'workflows-fc6cd.firebaseapp.com',
    storageBucket: 'workflows-fc6cd.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyABrBcCItjkUNiWEVS_ZKrXMXVyu1qhPx8',
    appId: '1:722933984234:android:59bec944cfe7839768a093',
    messagingSenderId: '722933984234',
    projectId: 'workflows-fc6cd',
    storageBucket: 'workflows-fc6cd.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBZgJYpONFJ8toHziU9Cd95IUdIrTxWkSk',
    appId: '1:722933984234:ios:041d13051aa045fb68a093',
    messagingSenderId: '722933984234',
    projectId: 'workflows-fc6cd',
    storageBucket: 'workflows-fc6cd.firebasestorage.app',
    iosBundleId: 'com.example.movilWorkflow',
  );
}
