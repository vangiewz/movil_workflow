// Firebase options loaded from compile-time defines.
// Keep real values out of version control by using --dart-define or
// --dart-define-from-file=.env
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static const String _webApiKey = String.fromEnvironment(
    'FIREBASE_WEB_API_KEY',
  );
  static const String _webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const String _webMessagingSenderId = String.fromEnvironment(
    'FIREBASE_WEB_MESSAGING_SENDER_ID',
  );
  static const String _webProjectId = String.fromEnvironment(
    'FIREBASE_WEB_PROJECT_ID',
  );
  static const String _webAuthDomain = String.fromEnvironment(
    'FIREBASE_WEB_AUTH_DOMAIN',
  );
  static const String _webStorageBucket = String.fromEnvironment(
    'FIREBASE_WEB_STORAGE_BUCKET',
  );

  static const String _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const String _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const String _androidMessagingSenderId = String.fromEnvironment(
    'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
  );
  static const String _androidProjectId = String.fromEnvironment(
    'FIREBASE_ANDROID_PROJECT_ID',
  );
  static const String _androidStorageBucket = String.fromEnvironment(
    'FIREBASE_ANDROID_STORAGE_BUCKET',
  );

  static const String _iosApiKey = String.fromEnvironment(
    'FIREBASE_IOS_API_KEY',
  );
  static const String _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _iosMessagingSenderId = String.fromEnvironment(
    'FIREBASE_IOS_MESSAGING_SENDER_ID',
  );
  static const String _iosProjectId = String.fromEnvironment(
    'FIREBASE_IOS_PROJECT_ID',
  );
  static const String _iosStorageBucket = String.fromEnvironment(
    'FIREBASE_IOS_STORAGE_BUCKET',
  );
  static const String _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
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
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => _required(
    FirebaseOptions(
      apiKey: _webApiKey,
      appId: _webAppId,
      messagingSenderId: _webMessagingSenderId,
      projectId: _webProjectId,
      authDomain: _webAuthDomain,
      storageBucket: _webStorageBucket,
    ),
    platform: 'web',
    requiredKeys: const [
      'FIREBASE_WEB_API_KEY',
      'FIREBASE_WEB_APP_ID',
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
      'FIREBASE_WEB_PROJECT_ID',
      'FIREBASE_WEB_AUTH_DOMAIN',
      'FIREBASE_WEB_STORAGE_BUCKET',
    ],
  );

  static FirebaseOptions get android => _required(
    FirebaseOptions(
      apiKey: _androidApiKey,
      appId: _androidAppId,
      messagingSenderId: _androidMessagingSenderId,
      projectId: _androidProjectId,
      storageBucket: _androidStorageBucket,
    ),
    platform: 'android',
    requiredKeys: const [
      'FIREBASE_ANDROID_API_KEY',
      'FIREBASE_ANDROID_APP_ID',
      'FIREBASE_ANDROID_MESSAGING_SENDER_ID',
      'FIREBASE_ANDROID_PROJECT_ID',
      'FIREBASE_ANDROID_STORAGE_BUCKET',
    ],
  );

  static FirebaseOptions get ios => _required(
    FirebaseOptions(
      apiKey: _iosApiKey,
      appId: _iosAppId,
      messagingSenderId: _iosMessagingSenderId,
      projectId: _iosProjectId,
      storageBucket: _iosStorageBucket,
      iosBundleId: _iosBundleId,
    ),
    platform: 'ios',
    requiredKeys: const [
      'FIREBASE_IOS_API_KEY',
      'FIREBASE_IOS_APP_ID',
      'FIREBASE_IOS_MESSAGING_SENDER_ID',
      'FIREBASE_IOS_PROJECT_ID',
      'FIREBASE_IOS_STORAGE_BUCKET',
      'FIREBASE_IOS_BUNDLE_ID',
    ],
  );

  static FirebaseOptions _required(
    FirebaseOptions options, {
    required String platform,
    required List<String> requiredKeys,
  }) {
    final hasMissing = requiredKeys.any(
      (key) => const String.fromEnvironment(key).isEmpty,
    );

    if (hasMissing) {
      throw UnsupportedError(
        'Missing Firebase configuration for $platform. '
        'Provide required --dart-define values: ${requiredKeys.join(', ')}',
      );
    }

    return options;
  }
}
