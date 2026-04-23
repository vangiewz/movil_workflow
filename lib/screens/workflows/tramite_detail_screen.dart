import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/tramite_model.dart';
import '../../models/plantilla_workflow.dart';
import '../../services/workflow_service.dart';
import 'package:go_router/go_router.dart';

class TramiteDetailScreen extends StatefulWidget {
  final Tramite tramite;
  const TramiteDetailScreen({super.key, required this.tramite});

  @override
  State<TramiteDetailScreen> createState() => _TramiteDetailScreenState();
}

class _TramiteDetailScreenState extends State<TramiteDetailScreen> {
  bool _isLoading = true;
  PlantillaWorkflow? _workflow;
  PasoWorkflow? _pasoActual;
  
  // Dynamic form state
  final Map<String, TextEditingController> _controllers = {};
  Map<String, dynamic> _schemaProperties = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      if (widget.tramite.estadoGlobal != 'FINALIZADO' && widget.tramite.pasoActualId != null) {
        final wf = await WorkflowService.getWorkflowById(widget.tramite.plantillaId);
        _workflow = wf;
        try {
           _pasoActual = wf.pasos.firstWhere((p) => p.id == widget.tramite.pasoActualId);
           if (_pasoActual!.departamentoId == null) {
              _parseSchema();
           }
        } catch(e) {
           // Paso not found
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
       if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
       }
    }
  }

  void _parseSchema() {
     final formJson = _pasoActual?.formularioJson;
     if (formJson != null && formJson['properties'] != null) {
       _schemaProperties = Map<String, dynamic>.from(formJson['properties']);
       _schemaProperties.forEach((key, spec) {
         _controllers[key] = TextEditingController();
         if (spec['type'] == 'boolean') {
            _controllers[key]!.text = 'false';
         }
       });
     }
  }

  @override
  void dispose() {
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _submitPaso() async {
    // Validar Requeridos
    final formJson = _pasoActual?.formularioJson;
    final List<dynamic> authRequired = formJson != null && formJson['required'] != null ? formJson['required'] : [];

    for (final key in authRequired) {
      if (_controllers[key] != null && _controllers[key]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor llena el campo: $key'), backgroundColor: AppColors.error));
        return; 
      }
    }

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> formData = {};
    _controllers.forEach((key, controller) {
      final propSpec = _schemaProperties[key];
      if (propSpec != null) {
        if (propSpec['type'] == 'number' || propSpec['type'] == 'integer') {
          formData[key] = num.tryParse(controller.text) ?? 0;
        } else if (propSpec['type'] == 'boolean') {
          formData[key] = (controller.text == 'true');
        } else {
          formData[key] = controller.text;
        }
      } else {
        formData[key] = controller.text;
      }
    });

    try {
      await WorkflowService.responderPaso(widget.tramite.id!, _pasoActual!.id, formData);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requerimiento completado.')));
         context.pop(); // Go back to list
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isSubmitting = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _submitDecision(String decision) async {
    setState(() => _isSubmitting = true);
    try {
      await WorkflowService.responderPaso(widget.tramite.id!, _pasoActual!.id, {}, decision);
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decisión enviada.')));
         context.pop(); // Go back to list
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isSubmitting = false);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  // --- Widgets for Dynamic Form ---
  Widget _buildDynamicField(String key, dynamic spec, String label) {
    final type = spec['type'] ?? 'string';
    final format = spec['format'];

    if (type == 'boolean') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: StatefulBuilder(
          builder: (context, setStateBool) {
            bool val = _controllers[key]!.text == 'true';
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surfaceVariant
              ),
              child: SwitchListTile(
                title: Text(label.toUpperCase(), style: const TextStyle(fontSize: 14)),
                value: val,
                activeColor: AppColors.primaryLight,
                onChanged: (v) {
                  setStateBool(() {
                     _controllers[key]!.text = v.toString();
                  });
                },
              ),
            );
          }
        ),
      );
    } else if (type == 'string' && format == 'date') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextField(
          controller: _controllers[key],
          readOnly: true,
          decoration: InputDecoration(
            labelText: label.toUpperCase(),
            hintText: 'Selecciona una fecha',
            prefixIcon: const Icon(Icons.calendar_month, color: AppColors.textSecondary),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              _controllers[key]!.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            }
          },
        ),
      );
    } else {
      final isNum = type == 'number' || type == 'integer';
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextField(
          controller: _controllers[key],
          keyboardType: isNum ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            labelText: label.toUpperCase(),
            hintText: 'Ingresar $key...',
            prefixIcon: isNum ? const Icon(Icons.numbers, color: AppColors.textSecondary) : null,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDone = widget.tramite.estadoGlobal == 'FINALIZADO';
    bool needsClientResponse = _pasoActual != null && _pasoActual!.departamentoId == null && !isDone;

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
               Text('Progreso: ${widget.tramite.nombrePlantilla}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
               const SizedBox(height: 8),
               Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: isDone ? Colors.green.withOpacity(0.1) : AppColors.surfaceVariant,
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: isDone ? Colors.green : AppColors.border),
                 ),
                 child: Row(
                   children: [
                      Icon(isDone ? Icons.check_circle : Icons.hourglass_top, color: isDone ? Colors.green : AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isDone ? 'Trámite Completado' : 'Esperando paso: ${_pasoActual?.nombrePaso ?? "Desconocido"}',
                          style: TextStyle(color: isDone ? Colors.green : AppColors.primaryLight, fontWeight: FontWeight.bold),
                        )
                      )
                   ],
                 ),
               ),
               
               if (!isDone && !needsClientResponse)
                 const Padding(
                   padding: EdgeInsets.only(top: 24.0),
                   child: Text('Su trámite está siendo procesado por el departamento designado. Se le notificará al avanzar.', style: TextStyle(color: AppColors.textSecondary)),
                 ),

               if (needsClientResponse)
                 Padding(
                   padding: const EdgeInsets.only(top: 32.0),
                   child: _pasoActual?.tipo == 'DECISION' ? Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                        const Text('Decisión Requerida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        const SizedBox(height: 8),
                        const Text('Por favor seleccione una de las siguientes opciones para continuar.', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 24),
                        if (_pasoActual?.siguientes != null)
                          ..._pasoActual!.siguientes!.keys.map((opcion) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: _isSubmitting
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: () => _submitDecision(opcion),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  child: Text(opcion, style: const TextStyle(fontSize: 16)),
                                ),
                          )).toList(),
                     ],
                   ) : Column(
                     crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                        const Text('Requerimiento del Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                        const SizedBox(height: 8),
                        const Text('Es necesario que complete la siguiente información para que su trámite avance.', style: TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 24),
                        ..._schemaProperties.entries.map((entry) {
                          final key = entry.key;
                          final spec = entry.value;
                          final label = spec['description'] ?? key;
                          return _buildDynamicField(key, spec, label.toString());
                        }),
                        const SizedBox(height: 32),
                        _isSubmitting
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                              onPressed: _submitPaso,
                              child: const Text('Enviar Requerimiento'),
                            )
                     ],
                   )
                 )
            ],
          )
    );
  }
}
