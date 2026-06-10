import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../config/database_helper.dart';
import 'network_status_service.dart';
import 'offline_queue_service.dart';

class ApiService {
  static String get baseUrl {
    final useProduction = dotenv.env['USE_PRODUCTION_API'] == 'true';
    if (useProduction) {
      return dotenv.env['API_URL_PROD'] ??
          'https://workflow-backend-rekte.azurewebsites.net/api';
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
    final urlStr = '$baseUrl$endpoint';
    final url = Uri.parse(urlStr);
    final headers = await _getHeaders();

    if (!NetworkStatusService().isOnline) {
      // Offline -> Encolar en SQLite
      await OfflineQueueService().enqueue(urlStr, isPatch ? 'PATCH' : 'POST', body, headers);
      return http.Response(jsonEncode({'message': 'Operación encolada offline', 'offline': true}), 202);
    }

    try {
      if (isPatch) {
        return await http.patch(url, headers: headers, body: jsonEncode(body));
      } else {
        return await http.post(url, headers: headers, body: jsonEncode(body));
      }
    } catch (e) {
      // Si falla por red imprevista, también encolar
      await OfflineQueueService().enqueue(urlStr, isPatch ? 'PATCH' : 'POST', body, headers);
      return http.Response(jsonEncode({'message': 'Operación encolada por fallo de red', 'offline': true}), 202);
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

    if (!NetworkStatusService().isOnline) {
      return http.Response(jsonEncode({'error': 'No se pueden enviar archivos sin conexión a internet'}), 503);
    }

    var request = http.MultipartRequest('POST', url);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['datos'] = jsonEncode(bodyJson);

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
    final urlStr = '$baseUrl$endpoint';
    final url = Uri.parse(urlStr);
    final headers = await _getHeaders();
    final db = await DatabaseHelper.instance.database;

    if (!NetworkStatusService().isOnline) {
      // Offline -> Retornar caché local
      final cached = await db.query('http_cache', where: 'url = ?', whereArgs: [urlStr]);
      if (cached.isNotEmpty) {
        debugPrint("Retornando caché offline para $urlStr");
        return http.Response(cached.first['response'] as String, 200);
      }
      return http.Response(jsonEncode({'error': 'Sin conexión y sin datos en caché'}), 503);
    }

    try {
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        // Guardar en caché local
        await db.insert('http_cache', {
          'url': urlStr,
          'response': response.body,
          'timestamp': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return response;
    } catch (e) {
      // Fallo de red imprevisto -> intentar caché
      final cached = await db.query('http_cache', where: 'url = ?', whereArgs: [urlStr]);
      if (cached.isNotEmpty) {
        debugPrint("Fallo de red, retornando caché para $urlStr");
        return http.Response(cached.first['response'] as String, 200);
      }
      return http.Response(jsonEncode({'error': 'Error de conexión: $e'}), 500);
    }
  }
}
