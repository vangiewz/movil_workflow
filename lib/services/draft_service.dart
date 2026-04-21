import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/plantilla_workflow.dart';

class DraftService {
  static const String key = 'paid_drafts';

  // Guarda un draft después de pagar
  static Future<void> savePaidDraft(PlantillaWorkflow workflow) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> drafts = prefs.getStringList(key) ?? [];
    
    // Evitar duplicados exactos si ya estaba
    final workflowJson = jsonEncode({
      'id': workflow.id,
      'nombre': workflow.nombre,
      'descripcion': workflow.descripcion,
      'isActive': workflow.isActive,
      'categoria': workflow.categoria,
      'costoBase': workflow.costoBase,
      'formularioCliente': workflow.formularioCliente,
    });

    drafts.add(workflowJson);
    await prefs.setStringList(key, drafts);
  }

  // Lista de drafts pendientes de llenado del form y mandarse al backend
  static Future<List<PlantillaWorkflow>> getPaidDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> drafts = prefs.getStringList(key) ?? [];
    return drafts.map((d) => PlantillaWorkflow.fromJson(jsonDecode(d))).toList();
  }

  static Future<void> removePaidDraft(String templateId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> drafts = prefs.getStringList(key) ?? [];
    
    // Remover el primero que coincida con este ID (por si tiene varios del mismo tipo)
    int index = drafts.indexWhere((d) {
      final map = jsonDecode(d);
      return map['id'] == templateId;
    });

    if (index != -1) {
      drafts.removeAt(index);
      await prefs.setStringList(key, drafts);
    }
  }
}
