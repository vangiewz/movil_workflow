import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static String get baseUrl {
    final useProduction = dotenv.env['USE_PRODUCTION_API'] == 'true';
    if (useProduction) {
      return dotenv.env['API_URL_PROD'] ??
          'https://api-backend-5axms.azurewebsites.net/api';
    } else {
      return dotenv.env['API_URL_LOCAL'] ?? 'http://localhost:8080/api';
    }
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

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool isPatch = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      if (isPatch) {
        return await http.patch(url, headers: headers, body: jsonEncode(body));
      } else {
        return await http.post(url, headers: headers, body: jsonEncode(body));
      }
    } catch (e) {
      // Retornar un response 500 fake para que el AuthService lo ataje sin crashear la UI
      return http.Response(jsonEncode({'error': 'Error de conexión: $e'}), 500);
    }
  }

  static Future<http.Response> postMultipart(
    String endpoint,
    Map<String, dynamic> bodyJson,
    Map<String, String> files,
  ) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    var request = http.MultipartRequest('POST', url);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Agregar JSON body en un form field normal o part
    request.fields['datos'] = jsonEncode(bodyJson);

    // Agregar archivos
    for (var entry in files.entries) {
      request.files.add(
        await http.MultipartFile.fromPath(entry.key, entry.value),
      );
    }

    try {
      final streamedResponse = await request.send();
      return await http.Response.fromStream(streamedResponse);
    } catch (e) {
      return http.Response(
        jsonEncode({'error': 'Error de conexión multipart: $e'}),
        500,
      );
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
