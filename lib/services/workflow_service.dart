import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plantilla_workflow.dart';
import '../models/tramite_model.dart';
import 'api_service.dart';

class WorkflowService {
  static Future<List<PlantillaWorkflow>> getWorkflows() async {
    final response = await ApiService.get('/workflows');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      
      // Filtrar lógica (Cliente solo ve EXTERNO)
      final prefs = await SharedPreferences.getInstance();
      final tipoUsuario = prefs.getString('tipoUsuario') ?? 'CLIENTE';

      List<PlantillaWorkflow> temp = jsonList
          .map((data) => PlantillaWorkflow.fromJson(data))
          .where((pw) => pw.isActive) // Solo activos
          .toList();

      if (tipoUsuario == 'CLIENTE') {
        temp = temp.where((pw) => pw.categoria.toUpperCase() == 'EXTERNO').toList();
      }

      return temp;
    } else {
      throw Exception('Error al cargar la lista de trámites');
    }
  }

  static Future<Tramite> createTramite(String plantillaId, Map<String, dynamic> datosFormulario, {Map<String, String>? files}) async {
    final prefs = await SharedPreferences.getInstance();
    final clienteId = prefs.getString('userId') ?? 'DESCONOCIDO';

    final requestBody = {
      'plantillaId': plantillaId,
      'clienteId': clienteId,
      'datosCliente': datosFormulario,
    };

    final response = (files != null && files.isNotEmpty)
        ? await ApiService.postMultipart('/tramites', requestBody, files)
        : await ApiService.post('/tramites', requestBody);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return Tramite.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al iniciar el trámite: ${response.body}');
    }
  }

  // Get active workflows for a client
  static Future<List<Tramite>> getActiveTramites() async {
    final response = await ApiService.get('/tramites/cliente');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((data) => Tramite.fromJson(data)).toList();
    } else {
      throw Exception('Error al cargar trámites activos');
    }
  }

  // Fetch a single Workflow (Plantilla) by its ID to get current step schema
  static Future<PlantillaWorkflow> getWorkflowById(String id) async {
    final response = await ApiService.get('/workflows/$id');
    if (response.statusCode == 200) {
      return PlantillaWorkflow.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Error al cargar detalle del Workflow');
    }
  }

  // Submit step response
  static Future<void> responderPaso(String tramiteId, String pasoId, Map<String, dynamic> respuesta, {String? decisionElegida, Map<String, String>? files}) async {
    final body = {
      "pasoId": pasoId,
      "respuesta": respuesta
    };
    if (decisionElegida != null) {
      body["decisionElegida"] = decisionElegida;
    }
    
    // Si hay archivos, usamos postMultipart
    final response = (files != null && files.isNotEmpty)
        ? await ApiService.postMultipart('/tramites/$tramiteId/responder', body, files)
        : await ApiService.post('/tramites/$tramiteId/responder', body);

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Error al enviar respuesta: ${response.body}');
    }
  }

  /// Obtiene el resumen generado por IA de un trámite finalizado.
  static Future<Map<String, dynamic>> getResumenTramite(String tramiteId) async {
    final response = await ApiService.get('/tramites/$tramiteId/resumen');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error al obtener resumen del trámite');
    }
  }
}
