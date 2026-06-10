import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/database_helper.dart';
import 'network_status_service.dart';

class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;

  bool _isProcessing = false;
  
  final _queueProcessedController = StreamController<void>.broadcast();
  Stream<void> get onQueueProcessed => _queueProcessedController.stream;

  OfflineQueueService._internal() {
    // Procesar al arrancar la app por si quedaron pendientes
    Future.delayed(const Duration(seconds: 2), () {
      processQueue();
    });

    // Escuchar cambios de red para procesar la cola
    NetworkStatusService().onConnectivityChanged.listen((results) {
      // Evaluamos directamente el resultado para evitar condición de carrera con NetworkStatusService
      if (!results.contains(ConnectivityResult.none)) {
        processQueue();
      }
    });
  }

  /// Añade una petición a la cola SQLite
  Future<void> enqueue(String url, String method, Map<String, dynamic>? body, Map<String, String>? headers) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('offline_queue', {
      'url': url,
      'method': method,
      'body': body != null ? jsonEncode(body) : null,
      'headers': headers != null ? jsonEncode(headers) : null,
      'timestamp': DateTime.now().toIso8601String(),
    });
    debugPrint("Petición encolada: $method $url");
  }

  /// Procesa la cola secuencialmente
  Future<void> processQueue() async {
    if (_isProcessing) return;
    
    // Doble check de conexión
    final isOnline = await NetworkStatusService().checkConnectionNow();
    if (!isOnline) return;

    _isProcessing = true;
    final db = await DatabaseHelper.instance.database;
    final pending = await db.query('offline_queue', orderBy: 'timestamp ASC');

    if (pending.isEmpty) {
      _isProcessing = false;
      _queueProcessedController.add(null);
      return;
    }

    debugPrint("Procesando ${pending.length} peticiones encoladas...");

    for (var item in pending) {
      final id = item['id'] as int;
      final url = item['url'] as String;
      final method = item['method'] as String;
      final bodyStr = item['body'] as String?;
      final headersStr = item['headers'] as String?;

      final headers = headersStr != null ? Map<String, String>.from(jsonDecode(headersStr)) : <String, String>{};
      final uri = Uri.parse(url);

      bool success = false;
      try {
        http.Response? response;
        if (method == 'POST') {
          response = await http.post(uri, headers: headers, body: bodyStr);
        } else if (method == 'PUT') {
          response = await http.put(uri, headers: headers, body: bodyStr);
        } else if (method == 'PATCH') {
          response = await http.patch(uri, headers: headers, body: bodyStr);
        } else if (method == 'DELETE') {
          response = await http.delete(uri, headers: headers);
        }

        if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
          success = true;
        } else if (response != null && response.statusCode >= 400 && response.statusCode < 500) {
          // Errores del cliente (ej. 400 Bad Request, 404 Not Found),
          // probablemente nunca se procesarán con éxito, así que lo marcamos como success para sacarlo de la cola
          success = true; 
        }
      } catch (e) {
        debugPrint("Error al sincronizar petición $id: $e");
        // Error de red, detenemos el proceso y lo intentamos luego
        break; 
      }

      if (success) {
        await db.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
        debugPrint("Petición $id sincronizada exitosamente.");
      }
    }

    _isProcessing = false;
    _queueProcessedController.add(null);
  }
}
