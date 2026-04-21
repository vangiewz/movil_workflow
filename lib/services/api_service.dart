import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Ajusta la URL según corresponda (ej. http://10.0.2.2:8080 para emulador Android)
  static String get baseUrl {
    return 'http://localhost:8080/api';
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> post(String endpoint, Map<String, dynamic> body, {bool isPatch = false}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      if (isPatch) {
        return await http.patch(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
      } else {
        return await http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );
      }
    } catch (e) {
      // Retornar un response 500 fake para que el AuthService lo ataje sin crashear la UI
      return http.Response(jsonEncode({'error': 'Error de conexión: $e'}), 500);
    }
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      return await http.get(url, headers: headers);
    } catch (e) {
      return http.Response(jsonEncode({'error': 'Error de conexión: $e'}), 500);
    }
  }
}
