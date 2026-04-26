import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Canal global para alta prioridad en Android
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'Notificaciones Importantes', // title
  description: 'Este canal se usa para notificaciones importantes.', // description
  importance: Importance.high,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Manejador en segundo plano para notificaciones push
  debugPrint("Notificación recibida en background: ${message.messageId}");
}

class PushNotificationService {
  static Future<void> init() async {
    if (kIsWeb) return;
    
    // Registrar el handler para background/killed state
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Inicializar FlutterLocalNotifications (Necesario para Foreground en Android)
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // Crear el canal en Android
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configurar notificaciones en primer plano para iOS
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Escuchar mensajes cuando la app está en primer plano (foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Mensaje recibido en Foreground: ${message.data}');

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // Mostrar la notificación usando local_notifications si existe payload de notification
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon ?? '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  /// Solicita permisos de notificaciones y retorna true si se concedieron.
  static Future<bool> requestPermissions() async {
    try {
      // 1. Pedir permiso vía Firebase (iOS/Web)
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // 2. En Android 13+, forzar el diálogo nativo vía permission_handler
      var status = await Permission.notification.status;
      if (status.isDenied) {
        status = await Permission.notification.request();
      }

      if (status.isPermanentlyDenied) {
        debugPrint("Notificaciones permanentemente denegadas. Abriendo Ajustes...");
        await openAppSettings();
        return false;
      }

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;

      debugPrint("Permisos de notificaciones: ${granted ? 'CONCEDIDOS' : 'DENEGADOS'}");
      return granted;
    } catch (e) {
      debugPrint("Error solicitando permisos de notificación: $e");
      return false;
    }
  }

  /// Obtiene el FCM token real. Retorna null si Firebase no está configurado.
  /// NUNCA retorna un dummy token.
  static Future<String?> getToken() async {
    try {
      if (kIsWeb) return null;
      final token = await FirebaseMessaging.instance.getToken()
          .timeout(const Duration(seconds: 5));
      debugPrint("FCM Token obtenido: ${token != null ? '${token.substring(0, 20)}...' : 'null'}");
      return token;
    } catch (e) {
      debugPrint("No se pudo obtener FCM token: $e");
      return null; // Retornar null, NUNCA un dummy
    }
  }
}
