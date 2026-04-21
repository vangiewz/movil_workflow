import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  static Future<void> initialize() async {
    try {
      // Firebase ya debe haber sido inicializado en main.dart
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Pedir permisos en iOS/Web
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (kDebugMode) {
        print('User granted permission: ${settings.authorizationStatus}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error inicializando push notifications (Firebase no configurado?): $e');
      }
    }
  }

  static Future<String?> getToken() async {
    try {
      if (kIsWeb) return null; // Previene infinito loading en la Web
      // Intentamos recuperar el token
      return await FirebaseMessaging.instance.getToken().timeout(const Duration(seconds: 3));
    } catch (e) {
      if (kDebugMode) {
        print('No se pudo obtener FCM token, usando dummy token para depuración: $e');
      }
      return "dummy-fcm-token-pending-firebase-config";
    }
  }
}
