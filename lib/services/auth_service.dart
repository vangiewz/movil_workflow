import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'push_notification_service.dart';

class AuthService {
  // Login global para cualquier empleado o cliente
  static Future<Map<String, dynamic>> login(String email, String password) async {
    // 1. Pedir permisos de notificaciones ANTES de obtener el token
    await PushNotificationService.requestPermissions();

    // 2. Obtener el FCM token real (null si no se pudo)
    String? fcmToken = await PushNotificationService.getToken();

    final response = await ApiService.post('/auth/mobile/login', {
      'email': email,
      'password': password,
      if (fcmToken != null) 'fcmToken': fcmToken,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _saveSession(data);
      return {'success': true, 'data': data};
    } else {
      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['error'] ?? 'Error desconocido'};
    }
  }

  // Registro exclusivo para clientes
  static Future<Map<String, dynamic>> registerClient({
    required String nombre,
    required String email,
    required String password,
    String? telefono,
  }) async {
    final response = await ApiService.post('/auth/cliente/register', {
      'nombre': nombre,
      'email': email,
      'password': password,
      'telefono': telefono ?? '',
    });

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // El backend devuelve auto-login con token
      await _saveSession(data);
      return {'success': true, 'data': data};
    } else {
      final error = jsonDecode(response.body);
      return {'success': false, 'message': error['error'] ?? 'Error registrando'};
    }
  }

  static Future<void> _saveSession(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    if (data['token'] != null) {
      await prefs.setString('jwt_token', data['token']);
    }
    if (data['id'] != null) {
      await prefs.setString('userId', data['id']);
    }
    if (data['tipoUsuario'] != null) {
      await prefs.setString('tipoUsuario', data['tipoUsuario']);
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('userId');
    await prefs.remove('tipoUsuario');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }
}
