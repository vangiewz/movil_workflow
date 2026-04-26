import 'package:flutter/material.dart';
import 'dart:ui';
import '../../constants/app_colors.dart';
import '../../models/tramite_model.dart';
import '../../models/plantilla_workflow.dart';
import '../../services/workflow_service.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';

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
  final Map<String, String> _selectedFiles = {};
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
      final rawType = _schemaProperties[key]?['type']?.toString().toLowerCase();
      final rawFormat = _schemaProperties[key]?['format']?.toString().toLowerCase();
      final isFile = rawType == 'file' || rawFormat == 'file' || rawFormat == 'binary' || rawType == 'archivo';
      if (isFile) {
        if (!_selectedFiles.containsKey(key)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor sube el archivo: $key'), backgroundColor: AppColors.error));
          return;
        }
      } else if (_controllers[key] != null && _controllers[key]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor llena el campo: $key'), backgroundColor: AppColors.error));
        return; 
      }
    }

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> formData = {};
    _controllers.forEach((key, controller) {
      final propSpec = _schemaProperties[key];
      if (propSpec != null) {
        final rawType = propSpec['type']?.toString().toLowerCase();
        final rawFormat = propSpec['format']?.toString().toLowerCase();
        final isFile = rawType == 'file' || rawFormat == 'file' || rawFormat == 'binary' || rawType == 'archivo';

        if (rawType == 'number' || rawType == 'integer') {
          formData[key] = num.tryParse(controller.text) ?? 0;
        } else if (rawType == 'boolean') {
          formData[key] = (controller.text == 'true');
        } else if (isFile) {
          // Ya lo pasamos en _selectedFiles
        } else {
          formData[key] = controller.text;
        }
      } else {
        formData[key] = controller.text;
      }
    });

    try {
      await WorkflowService.responderPaso(widget.tramite.id!, _pasoActual!.id, formData, files: _selectedFiles);
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
      await WorkflowService.responderPaso(widget.tramite.id!, _pasoActual!.id, {}, decisionElegida: decision);
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
    final type = (spec['type']?.toString() ?? 'string').toLowerCase();
    final format = spec['format']?.toString().toLowerCase();

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
    } else if ((type == 'string' && (format == 'date' || format == 'date-time')) || type == 'date' || type == 'datetime' || type == 'date-time') {
      final isDateTime = format == 'date-time' || type == 'datetime' || type == 'date-time';
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextField(
          controller: _controllers[key],
          readOnly: true,
          decoration: InputDecoration(
            labelText: label.toUpperCase(),
            hintText: isDateTime ? 'Selecciona fecha y hora' : 'Selecciona una fecha',
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
              if (isDateTime) {
                if (!context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  _controllers[key]!.text = dt.toIso8601String();
                }
              } else {
                _controllers[key]!.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              }
            }
          },
        ),
      );
    } else if (type == 'file' || format == 'file' || format == 'binary' || type == 'archivo') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: StatefulBuilder(
          builder: (context, setStateFile) {
            final hasFile = _selectedFiles.containsKey(key);
            final fileName = hasFile ? _selectedFiles[key]!.split('/').last : 'Ningún archivo seleccionado';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () async {
                    FilePickerResult? result = await FilePicker.pickFiles();
                    if (result != null && result.files.single.path != null) {
                      setStateFile(() {
                        _selectedFiles[key] = result.files.single.path!;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: hasFile ? AppColors.primary : AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.surfaceVariant
                    ),
                    child: Row(
                      children: [
                        Icon(hasFile ? Icons.file_present : Icons.upload_file, color: hasFile ? AppColors.primaryLight : AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(fileName, style: TextStyle(color: hasFile ? AppColors.textPrimary : AppColors.textSecondary, overflow: TextOverflow.ellipsis))),
                        if (hasFile)
                           IconButton(
                             icon: const Icon(Icons.close, color: AppColors.error, size: 20),
                             onPressed: () {
                               setStateFile(() { _selectedFiles.remove(key); });
                             },
                           )
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        )
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

  /// Detects ACTIVIDAD with multiple non-default routes (AI edge case)
  bool get _isMultiRoute {
    if (_pasoActual == null || _pasoActual!.siguientes == null) return false;
    final sig = _pasoActual!.siguientes!;
    return sig.length > 1 && !sig.containsKey('default');
  }

  Widget _buildClientResponseWidget() {
    final isDecision = _pasoActual?.tipo == 'DECISION';
    final isMultiRoute = _isMultiRoute;

    // Pure DECISION — only buttons, no form
    if (isDecision) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Decisión Requerida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(height: 8),
          const Text('Seleccione una de las opciones para continuar.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          if (_pasoActual?.siguientes != null)
            ..._pasoActual!.siguientes!.keys.map((opcion) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: _isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: () => _submitDecision(opcion),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(opcion, style: const TextStyle(fontSize: 16)),
                  ),
            )).toList(),
        ],
      );
    }

    // ACTIVIDAD with multi-route — show form + route selection buttons
    if (isMultiRoute) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Información y Selección', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
          const SizedBox(height: 8),
          const Text('Complete la información y seleccione la opción que corresponda.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ..._schemaProperties.entries.map((entry) {
            final key = entry.key;
            final spec = entry.value;
            final label = spec['description'] ?? key;
            return _buildDynamicField(key, spec, label.toString());
          }),
          const SizedBox(height: 24),
          const Text('Seleccione una opción:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ..._pasoActual!.siguientes!.keys.map((opcion) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _isSubmitting
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton(
                  onPressed: () => _submitDecision(opcion),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: Text(opcion, style: const TextStyle(fontSize: 16)),
                ),
          )).toList(),
        ],
      );
    }

    // Normal ACTIVIDAD — form + submit button
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Requerimiento del Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.secondary)),
        const SizedBox(height: 8),
        const Text('Complete la siguiente información para que su trámite avance.', style: TextStyle(color: AppColors.textSecondary)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDone = widget.tramite.estadoGlobal == 'FINALIZADO';
    bool needsClientResponse = _pasoActual != null && _pasoActual!.departamentoId == null && !isDone;
    
    bool showInvoice = widget.tramite.invoiceUrl != null && 
                       widget.tramite.invoiceUrl!.isNotEmpty && 
                       ['PENDIENTE', 'EN_PROCESO', 'FINALIZADO'].contains(widget.tramite.estadoGlobal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento'),
        actions: [
          if (showInvoice)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Ver Factura',
              onPressed: () async {
                final urlString = widget.tramite.invoiceUrl!;
                final url = Uri.parse(urlString.startsWith('http') ? urlString : 'https://$urlString');
                try {
                  final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo abrir el enlace')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al abrir el enlace')));
                  }
                }
              },
            ),
        ],
      ),
      floatingActionButton: isDone ? FloatingActionButton(
        onPressed: () => _showResumenBottomSheet(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.help_outline_rounded, color: Colors.white, size: 28),
      ) : null,
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
                   child: _buildClientResponseWidget(),
                 )
            ],
          )
    );
  }

  void _showResumenBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResumenBottomSheet(tramiteId: widget.tramite.id),
    );
  }
}

// ── Bottom Sheet Widget ──
class _ResumenBottomSheet extends StatefulWidget {
  final String tramiteId;
  const _ResumenBottomSheet({required this.tramiteId});

  @override
  State<_ResumenBottomSheet> createState() => _ResumenBottomSheetState();
}

class _ResumenBottomSheetState extends State<_ResumenBottomSheet> {
  bool _loading = true;
  Map<String, dynamic>? _resumen;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchResumen();
  }

  Future<void> _fetchResumen() async {
    try {
      final data = await WorkflowService.getResumenTramite(widget.tramiteId);
      if (mounted) setState(() { _resumen = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.92),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: AppColors.textTertiary, borderRadius: BorderRadius.circular(2)),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.auto_awesome, color: AppColors.primaryLight, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Resumen del Trámite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                    IconButton(icon: const Icon(Icons.close, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
                  ]),
                ),
                const Divider(color: AppColors.border, height: 1),
                // Content
                Expanded(
                  child: _loading
                    ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text('Generando resumen con IA...', style: TextStyle(color: AppColors.textSecondary)),
                      ]))
                    : _error != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('No se pudo generar el resumen.', style: TextStyle(color: AppColors.error))))
                      : ListView(controller: scrollController, padding: const EdgeInsets.all(20), children: [
                          // Estado badge
                          _buildEstadoBadge(_resumen!['estado'] ?? 'Completado'),
                          const SizedBox(height: 16),
                          // Resumen
                          Text(_resumen!['resumen'] ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5)),
                          const SizedBox(height: 24),
                          // Pasos clave
                          if (_resumen!['pasosClave'] != null && (_resumen!['pasosClave'] as List).isNotEmpty) ...[
                            const Text('Puntos Clave', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            const SizedBox(height: 12),
                            ...(_resumen!['pasosClave'] as List).map((paso) => _buildPasoClave(paso)),
                            const SizedBox(height: 24),
                          ],
                          // Conclusión
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                            ),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              const Icon(Icons.info_outline, color: AppColors.primaryLight, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(_resumen!['conclusion'] ?? '', style: const TextStyle(color: AppColors.primaryLight, fontSize: 14, height: 1.4))),
                            ]),
                          ),
                        ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color bgColor; Color textColor;
    if (estado.toLowerCase().contains('aprobado')) {
      bgColor = Colors.green.withOpacity(0.15); textColor = Colors.green;
    } else if (estado.toLowerCase().contains('rechazado')) {
      bgColor = AppColors.error.withOpacity(0.15); textColor = AppColors.error;
    } else {
      bgColor = AppColors.info.withOpacity(0.15); textColor = AppColors.info;
    }
    return Align(alignment: Alignment.centerLeft, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(estado, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
    ));
  }

  Widget _buildPasoClave(dynamic paso) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 8, height: 8,
          decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(paso['nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 4),
          Text(paso['resultado'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ])),
      ]),
    );
  }
}
