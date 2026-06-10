import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../../constants/app_colors.dart';
import '../../models/tramite_model.dart';
import '../../models/plantilla_workflow.dart';
import '../../services/workflow_service.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
  List<PasoWorkflow> _activeClientSteps = [];
  late Tramite _tramiteState;

  // Dynamic form state
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<Map<String, TextEditingController>>> _gridControllers = {};
  final Map<String, String> _selectedFiles = {};
  
  // Maps for live uploads
  final Map<String, double> _uploadProgress = {};
  final Map<String, Map<String, dynamic>> _uploadedFiles = {};
  final Map<String, List<Map<String, dynamic>>> _historialMap = {};
  final Map<String, bool> _isDownloading = {};

  final _dio = Dio();
  Map<String, dynamic> _schemaProperties = {};
  bool _isSubmitting = false;

  bool _isAssisting = false;
  final TextEditingController _chatPromptController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceStatus = 'Pulsa "Usar Voz" y habla después de ver "Escuchando".';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tramiteState = widget.tramite;
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final updated = await WorkflowService.getTramiteById(_tramiteState.id);
      _tramiteState = updated;
      _procesarDocumentosEstaticos();

      if (_tramiteState.estadoGlobal != 'FINALIZADO' &&
          _tramiteState.pasosActualesIds.isNotEmpty) {
        final wf = await WorkflowService.getWorkflowById(
          _tramiteState.plantillaId,
        );
        _workflow = wf;
        try {
          _activeClientSteps = wf.pasos.where(
            (p) => _tramiteState.pasosActualesIds.contains(p.id) && p.departamentoId == null,
          ).toList();
          
          if (_activeClientSteps.isNotEmpty) {
            if (_pasoActual == null || !_activeClientSteps.any((p) => p.id == _pasoActual!.id)) {
              _pasoActual = _activeClientSteps.first;
            }
            _parseSchema();
          } else {
            _activeClientSteps = [];
            _pasoActual = wf.pasos.firstWhere(
              (p) => _tramiteState.pasosActualesIds.contains(p.id),
              orElse: () => wf.pasos.first
            );
          }
        } catch (e) {
          // Paso not found
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e, stacktrace) {
      print('=== ERROR EN FETCH DETAILS ===');
      print(e);
      print(stacktrace);
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _procesarDocumentosEstaticos() {
    _uploadedFiles.clear();
    _historialMap.clear();
    if (_tramiteState.documentos == null) return;
    
    for (var doc in _tramiteState.documentos!) {
       if (doc['esColaborativo'] == true) continue;
       final key = doc['campoKey'] as String?;
       if (key == null) continue;
       
       if (!_historialMap.containsKey(key)) {
         _historialMap[key] = [];
       }
       _historialMap[key]!.add(Map<String, dynamic>.from(doc));
    }
    
    for (var key in _historialMap.keys) {
       _historialMap[key]!.sort((a, b) => (b['version'] ?? 0).compareTo(a['version'] ?? 0));
       if (_historialMap[key]!.isNotEmpty) {
          _uploadedFiles[key] = _historialMap[key]!.first;
          _historialMap[key] = _historialMap[key]!.sublist(1);
       }
    }
  }

  void _parseSchema() {
    // Clear and dispose existing controllers to avoid contamination
    _controllers.forEach((key, ctrl) => ctrl.dispose());
    _controllers.clear();
    
    _gridControllers.forEach((key, rows) {
      for (var row in rows) {
        row.forEach((colKey, ctrl) => ctrl.dispose());
      }
    });
    _gridControllers.clear();
    _selectedFiles.clear();

    final formJson = _pasoActual?.formularioJson;
    if (formJson != null && formJson['properties'] != null) {
      _schemaProperties = Map<String, dynamic>.from(formJson['properties']);
      _schemaProperties.forEach((key, spec) {
        if (spec['type'] == 'array' || spec['type'] == 'grid') {
          _gridControllers[key] = <Map<String, TextEditingController>>[];
        } else {
          _controllers[key] = TextEditingController();
          if (spec['type'] == 'boolean') {
            _controllers[key]!.text = 'false';
          }
        }
      });
    }
  }

  @override
  void dispose() {
    for (var ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (var rows in _gridControllers.values) {
      for (var row in rows) {
        for (var ctrl in row.values) {
          ctrl.dispose();
        }
      }
    }
    _chatPromptController.dispose();
    super.dispose();
  }

  void _aplicarSugerenciaIA(Map<String, dynamic> sugerencia) {
    if (!mounted) return;
    setState(() {
      sugerencia.forEach((key, value) {
        if (_controllers.containsKey(key)) {
          _controllers[key]!.text = value.toString();
        } else if (_gridControllers.containsKey(key) && value is List) {
          _gridControllers[key]!.clear(); // Limpiamos la grilla actual
          final itemsSchema = _schemaProperties[key]?['items']?['properties'] as Map? ?? {};
          
          for (var item in value) {
            if (item is Map) {
               final newRow = <String, TextEditingController>{};
               itemsSchema.forEach((colKey, colSpec) {
                 final colType = (colSpec['type'] ?? 'string').toString().toLowerCase();
                 final itemVal = item[colKey];
                 if (itemVal != null) {
                    newRow[colKey.toString()] = TextEditingController(text: itemVal.toString());
                 } else {
                    newRow[colKey.toString()] = TextEditingController(text: colType == 'boolean' ? 'false' : '');
                 }
               });
               _gridControllers[key]!.add(newRow);
            }
          }
        }
      });
    });
  }

  Future<void> _solicitarAsistenciaIA({required String modo, required String mensaje}) async {
    if (_pasoActual == null) return;
    setState(() {
      _isAssisting = true;
      _voiceStatus = 'Procesando solicitud por $modo con IA...';
    });

    try {
      final response = await WorkflowService.asistirFormulario(_tramiteState.id, _pasoActual!.id, modo, mensaje);
      final sugerencia = response['sugerencia'] as Map<String, dynamic>?;
      final observacion = response['observacion'] as String?;

      if (sugerencia != null && sugerencia.isNotEmpty) {
        _aplicarSugerenciaIA(sugerencia);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(observacion ?? 'Formulario autocompletado con IA.'), backgroundColor: Colors.green));
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La IA no pudo deducir campos con esa instrucción.'), backgroundColor: Colors.orange));
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al procesar asistencia IA: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAssisting = false;
          _voiceStatus = 'Pulsa "Usar Voz" y habla después de ver "Escuchando".';
          if (modo == 'chat') _chatPromptController.clear();
        });
      }
    }
  }

  void _solicitarAsistenciaChat() {
    final mensaje = _chatPromptController.text.trim();
    if (mensaje.isEmpty || _isAssisting) return;
    _solicitarAsistenciaIA(modo: 'chat', mensaje: mensaje);
  }

  void _toggleVoiceInput() async {
    if (_isAssisting) return;
    
    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (val) {
         if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
         }
      },
      onError: (val) {
         setState(() {
           _isListening = false;
           _voiceStatus = 'Error de micrófono: ${val.errorMsg}';
         });
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _voiceStatus = 'Escuchando... habla ahora.';
      });
      _speech.listen(
        localeId: 'es_ES',
        onResult: (val) {
          _chatPromptController.text = val.recognizedWords;
          if (val.hasConfidenceRating && val.confidence > 0 && val.finalResult) {
             _solicitarAsistenciaIA(modo: 'voz', mensaje: val.recognizedWords);
          }
        },
      );
    } else {
      setState(() {
        _isListening = false;
        _voiceStatus = 'El usuario ha denegado el uso del micrófono o no es compatible.';
      });
    }
  }


  Future<void> _submitPaso() async {
    // Validar Requeridos
    final formJson = _pasoActual?.formularioJson;
    final List<dynamic> authRequired =
        formJson != null && formJson['required'] != null
        ? formJson['required']
        : [];

    for (final key in authRequired) {
      final rawType = _schemaProperties[key]?['type']?.toString().toLowerCase();
      final rawFormat = _schemaProperties[key]?['format']
          ?.toString()
          .toLowerCase();
      final isFile =
          rawType == 'file' ||
          rawFormat == 'file' ||
          rawFormat == 'binary' ||
          rawType == 'archivo' ||
          rawType == 'archivo_estatico';
      if (isFile) {
        if (!_uploadedFiles.containsKey(key)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Por favor sube el archivo: $key'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      } else if (rawType == 'array' || rawType == 'grid') {
        if (_gridControllers[key] == null || _gridControllers[key]!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Por favor agrega datos en: $key'),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      } else if (_controllers[key] != null &&
          _controllers[key]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Por favor llena el campo: $key'),
            backgroundColor: AppColors.error,
          ),
        );
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
        final isFile =
            rawType == 'file' ||
            rawFormat == 'file' ||
            rawFormat == 'binary' ||
            rawType == 'archivo' ||
            rawType == 'archivo_estatico';

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

    _gridControllers.forEach((key, rows) {
      final Map<String, dynamic> itemsSchema = {};
      if (_schemaProperties[key]?['items'] != null && _schemaProperties[key]?['items']?['properties'] != null) {
        (_schemaProperties[key]?['items']?['properties'] as Map).forEach((k, v) {
          itemsSchema[k.toString()] = Map<String, dynamic>.from(v as Map);
        });
      }
      final List<Map<String, dynamic>> gridData = [];
      for (var row in rows) {
        final Map<String, dynamic> rowData = {};
        row.forEach((colKey, controller) {
           final colSpec = itemsSchema[colKey] ?? {};
           final colType = colSpec['type']?.toString().toLowerCase();
           if (colType == 'number' || colType == 'integer') {
              rowData[colKey] = num.tryParse(controller.text) ?? 0;
           } else if (colType == 'boolean') {
              rowData[colKey] = controller.text.toLowerCase() == 'true';
           } else {
              rowData[colKey] = controller.text;
           }
        });
        gridData.add(rowData);
      }
      formData[key] = gridData;
    });

    try {
      await WorkflowService.responderPaso(
        _tramiteState.id,
        _pasoActual!.id,
        formData,
        files: _selectedFiles,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Requerimiento completado.')),
        );
      }

      // Fetch updated details instead of blindly popping
      final updated = await WorkflowService.getTramiteById(_tramiteState.id);
      if (mounted) {
        setState(() {
          _tramiteState = updated;
        });
      }

      if (updated.estadoGlobal == 'FINALIZADO') {
        if (mounted) {
          context.pop();
        }
        return;
      }

      if (_workflow != null) {
        final remaining = _workflow!.pasos.where(
          (p) => updated.pasosActualesIds.contains(p.id) && p.departamentoId == null,
        ).toList();

        if (remaining.isNotEmpty) {
          if (mounted) {
            setState(() {
              _activeClientSteps = remaining;
              _pasoActual = _activeClientSteps.first;
              _parseSchema();
              _isSubmitting = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Siguiente requerimiento: ${_pasoActual!.nombrePaso}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitDecision(String decision) async {
    setState(() => _isSubmitting = true);
    try {
      await WorkflowService.responderPaso(
        _tramiteState.id,
        _pasoActual!.id,
        {},
        decisionElegida: decision,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Decisión enviada.')));
      }

      // Fetch updated details instead of blindly popping
      final updated = await WorkflowService.getTramiteById(_tramiteState.id);
      if (mounted) {
        setState(() {
          _tramiteState = updated;
        });
      }

      if (updated.estadoGlobal == 'FINALIZADO') {
        if (mounted) {
          context.pop();
        }
        return;
      }

      if (_workflow != null) {
        final remaining = _workflow!.pasos.where(
          (p) => updated.pasosActualesIds.contains(p.id) && p.departamentoId == null,
        ).toList();

        if (remaining.isNotEmpty) {
          if (mounted) {
            setState(() {
              _activeClientSteps = remaining;
              _pasoActual = _activeClientSteps.first;
              _parseSchema();
              _isSubmitting = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Siguiente requerimiento: ${_pasoActual!.nombrePaso}'),
                backgroundColor: Colors.green,
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
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
                color: AppColors.surfaceVariant,
              ),
              child: SwitchListTile(
                title: Text(
                  label.toUpperCase(),
                  style: const TextStyle(fontSize: 14),
                ),
                value: val,
                activeThumbColor: AppColors.primaryLight,
                onChanged: (v) {
                  setStateBool(() {
                    _controllers[key]!.text = v.toString();
                  });
                },
              ),
            );
          },
        ),
      );
    } else if ((type == 'string' &&
            (format == 'date' || format == 'date-time')) ||
        type == 'date' ||
        type == 'datetime' ||
        type == 'date-time') {
      final isDateTime =
          format == 'date-time' || type == 'datetime' || type == 'date-time';
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextField(
          controller: _controllers[key],
          readOnly: true,
          decoration: InputDecoration(
            labelText: label.toUpperCase(),
            hintText: isDateTime
                ? 'Selecciona fecha y hora'
                : 'Selecciona una fecha',
            prefixIcon: const Icon(
              Icons.calendar_month,
              color: AppColors.textSecondary,
            ),
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
                  final dt = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                  _controllers[key]!.text = dt.toIso8601String();
                }
              } else {
                _controllers[key]!.text =
                    "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
              }
            }
          },
        ),
      );
    } else if (type == 'file' ||
        format == 'file' ||
        format == 'binary' ||
        type == 'archivo' ||
        type == 'archivo_estatico') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: StatefulBuilder(
          builder: (context, setStateFile) {
            final progress = _uploadProgress[key];
            final uploadedFile = _uploadedFiles[key];
            
            bool hasEditPermission = true;
            final permisos = spec['permisosPorDefecto'];
            if (permisos != null) {
               hasEditPermission = false;
               if (permisos is Iterable) {
                 for (var p in permisos) {
                    if (p is Map && p['role'] == 'CLIENTE' && (p['permission'] == 'EDICION' || p['permission'] == 'AMBOS')) {
                       hasEditPermission = true;
                       break;
                    }
                 }
               } else if (permisos is Map) {
                 // The map structure is { "CLIENTE": "AMBOS", "OTHER_ROLE": "LECTURA" }
                 final clientePerm = permisos['CLIENTE']?.toString().toUpperCase();
                 if (clientePerm == 'EDICION' || clientePerm == 'AMBOS') {
                    hasEditPermission = true;
                 }
               }
            }

            Widget uploadWidget;
            if (uploadedFile == null) {
               if (!hasEditPermission) {
                  uploadWidget = Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                       color: AppColors.surfaceVariant,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                       children: [
                          Icon(Icons.lock, color: AppColors.textSecondary),
                          SizedBox(width: 12),
                          Expanded(child: Text('Solo lectura. No hay archivo asociado a este campo.', style: TextStyle(color: AppColors.textSecondary))),
                       ]
                    )
                  );
               } else if (progress != null) {
                  uploadWidget = Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                     ),
                     child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           const Text('Subiendo documento...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                           const SizedBox(height: 8),
                           LinearProgressIndicator(value: progress / 100, backgroundColor: AppColors.surface, color: AppColors.primary),
                           const SizedBox(height: 4),
                           Align(alignment: Alignment.centerRight, child: Text('${progress.toStringAsFixed(0)}%', style: const TextStyle(color: AppColors.primaryLight, fontSize: 12))),
                        ]
                     )
                  );
               } else {
                  uploadWidget = InkWell(
                    onTap: () async {
                       FilePickerResult? result = await FilePicker.pickFiles();
                       if (result != null && result.files.single.path != null) {
                          final file = result.files.single;
                          final allowedFormats = spec['formatosPermitidos'] as List<dynamic>?;
                          if (allowedFormats != null && allowedFormats.isNotEmpty) {
                             final ext = '.${file.extension?.toLowerCase() ?? ''}';
                             if (!allowedFormats.contains(ext)) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Formato $ext no permitido.'), backgroundColor: AppColors.error));
                                return;
                             }
                          }
                          final maxMb = spec['tamanoMaximoMB'];
                          if (maxMb != null) {
                             final maxSize = (maxMb as num).toInt() * 1024 * 1024;
                             if (file.size > maxSize) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Supera límite de $maxMb MB.'), backgroundColor: AppColors.error));
                                return;
                             }
                          }
                          await _uploadLiveFile(file.path!, key, setStateFile);
                       }
                    },
                    child: Container(
                       padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                       decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surfaceVariant,
                       ),
                       child: const Row(
                          children: [
                             Icon(Icons.upload_file, color: AppColors.textSecondary),
                             SizedBox(width: 12),
                             Expanded(child: Text('Ningún archivo seleccionado', style: TextStyle(color: AppColors.textSecondary))),
                          ]
                       )
                    )
                  );
               }
            } else {
               final historyItems = _historialMap[key] ?? [];
               uploadWidget = Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Card(
                      elevation: 2,
                      color: AppColors.surfaceVariant,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.border)),
                      margin: EdgeInsets.zero,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           if (progress != null)
                              Padding(
                                 padding: const EdgeInsets.all(12),
                                 child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                       const Text('Subiendo reemplazo...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                       const SizedBox(height: 8),
                                       LinearProgressIndicator(value: progress / 100, backgroundColor: AppColors.surface, color: AppColors.primary),
                                    ]
                                 )
                              ),
                           ListTile(
                              onTap: () {
                                 if (uploadedFile['archivoId'] != null) {
                                    _downloadFile(uploadedFile['archivoId'], uploadedFile['nombreOriginal'] ?? 'documento_${uploadedFile['archivoId']}');
                                 }
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              leading: Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                                 child: const Icon(Icons.check_circle, color: Colors.green),
                              ),
                              title: Text(uploadedFile['nombreOriginal'] ?? 'Archivo', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                              subtitle: Text('Versión ${uploadedFile['version'] ?? 1}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              trailing: IconButton(
                                 icon: const Icon(Icons.download, color: AppColors.primaryLight),
                                 onPressed: () {
                                    if (uploadedFile['archivoId'] != null) {
                                       _downloadFile(uploadedFile['archivoId'], uploadedFile['nombreOriginal'] ?? 'documento_${uploadedFile['archivoId']}');
                                    }
                                 },
                              ),
                           )
                        ]
                      )
                   ),
                   if (hasEditPermission && progress == null) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                           FilePickerResult? result = await FilePicker.pickFiles();
                           if (result != null && result.files.single.path != null) {
                              final file = result.files.single;
                              final allowedFormats = spec['formatosPermitidos'] as List<dynamic>?;
                              if (allowedFormats != null && allowedFormats.isNotEmpty) {
                                 final ext = '.${file.extension?.toLowerCase() ?? ''}';
                                 if (!allowedFormats.contains(ext)) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Formato $ext no permitido.'), backgroundColor: AppColors.error));
                                    return;
                                 }
                              }
                              final maxMb = spec['tamanoMaximoMB'];
                              if (maxMb != null) {
                                 final maxSize = (maxMb as num).toInt() * 1024 * 1024;
                                 if (file.size > maxSize) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Supera límite de $maxMb MB.'), backgroundColor: AppColors.error));
                                    return;
                                 }
                              }
                              await _uploadLiveFile(file.path!, key, setStateFile);
                           }
                        },
                        child: Container(
                           padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                           decoration: BoxDecoration(
                              border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.primary.withOpacity(0.1),
                           ),
                           child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                 Icon(Icons.upload_file, color: AppColors.primaryLight, size: 18),
                                 SizedBox(width: 8),
                                 Text('Reemplazar Archivo', style: TextStyle(color: AppColors.primaryLight, fontWeight: FontWeight.w600, fontSize: 13)),
                              ]
                           )
                        )
                      )
                   ],
                   if (historyItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('Historial de Versiones', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...historyItems.map((hist) => Padding(
                         padding: const EdgeInsets.only(bottom: 4.0),
                         child: Card(
                            elevation: 0,
                            color: AppColors.surface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: AppColors.border.withOpacity(0.5))),
                            margin: EdgeInsets.zero,
                            child: ListTile(
                               dense: true,
                               onTap: () {
                                  if (hist['archivoId'] != null) {
                                     _downloadFile(hist['archivoId'], hist['nombreOriginal'] ?? 'documento_${hist['archivoId']}');
                                  }
                               },
                               leading: const Icon(Icons.history, color: AppColors.textSecondary, size: 20),
                               title: Text(hist['nombreOriginal'] ?? 'Archivo Antiguo', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                               subtitle: Text('Versión ${hist['version'] ?? 1}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                               trailing: const Icon(Icons.download, size: 18, color: AppColors.textSecondary),
                            )
                         )
                      )).toList()
                   ]
                 ]
               );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                uploadWidget
              ]
            );
          }
        )
      );
    } else if (type == 'array' || type == 'grid') {
      final Map<String, dynamic> itemsSchema = {};
      if (spec['items'] != null && spec['items']['properties'] != null) {
        (spec['items']['properties'] as Map).forEach((k, v) {
          itemsSchema[k.toString()] = Map<String, dynamic>.from(v as Map);
        });
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: StatefulBuilder(
          builder: (context, setStateGrid) {
             if (_gridControllers[key] == null) {
               _gridControllers[key] = <Map<String, TextEditingController>>[];
             }
             final rows = _gridControllers[key]!;
             return Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12)),
                 const SizedBox(height: 8),
                 ...rows.asMap().entries.map((entry) {
                    final index = entry.key;
                    final row = entry.value;
                    return Card(
                      color: AppColors.surfaceVariant,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Fila ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: AppColors.error),
                                  onPressed: () {
                                    setStateGrid(() {
                                      rows.removeAt(index);
                                    });
                                  }
                                )
                              ]
                            ),
                            ...itemsSchema.entries.map((colEntry) {
                               final colKey = colEntry.key;
                               final colSpec = colEntry.value;
                               final colLabel = colSpec['title'] ?? colSpec['description'] ?? colKey;
                               final colType = (colSpec['type'] ?? 'string').toString().toLowerCase();
                               
                               if (colType == 'boolean') {
                                 return Padding(
                                   padding: const EdgeInsets.only(bottom: 8.0),
                                   child: StatefulBuilder(
                                     builder: (context, setStateColBool) {
                                       bool val = row[colKey]!.text == 'true';
                                       return Container(
                                         decoration: BoxDecoration(
                                           border: Border.all(color: AppColors.border),
                                           borderRadius: BorderRadius.circular(8),
                                           color: AppColors.surface,
                                         ),
                                         child: SwitchListTile(
                                           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                           dense: true,
                                           title: Text(
                                             colLabel.toString().toUpperCase(),
                                             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                           ),
                                           value: val,
                                           activeThumbColor: AppColors.primaryLight,
                                           onChanged: (v) {
                                             setStateColBool(() {
                                               row[colKey]!.text = v.toString();
                                             });
                                           },
                                         ),
                                       );
                                     }
                                   ),
                                 );
                               }
                               
                               final isNum = colType == 'number' || colType == 'integer';
                               return Padding(
                                 padding: const EdgeInsets.only(bottom: 8),
                                 child: TextField(
                                   controller: row[colKey],
                                   keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                                   inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null,
                                   decoration: InputDecoration(
                                     labelText: colLabel.toString().toUpperCase(),
                                     hintText: isNum ? 'Ingresar número...' : 'Ingresar texto...',
                                     isDense: true,
                                     prefixIcon: isNum ? const Icon(Icons.numbers, size: 16) : null,
                                   ),
                                 ),
                               );
                            })
                          ]
                        )
                      )
                    );
                 }),
                 ElevatedButton.icon(
                   icon: const Icon(Icons.add),
                   label: const Text('Agregar Fila'),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: AppColors.primary.withOpacity(0.2),
                     foregroundColor: AppColors.primaryLight,
                     elevation: 0,
                   ),
                   onPressed: () {
                     setStateGrid(() {
                       final newRow = <String, TextEditingController>{};
                       itemsSchema.forEach((k, v) {
                         final colType = (v['type'] ?? 'string').toString().toLowerCase();
                         newRow[k] = TextEditingController(
                           text: colType == 'boolean' ? 'false' : '',
                         );
                       });
                       rows.add(newRow);
                     });
                   }
                 )
               ]
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
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: isNum ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))] : null,
          decoration: InputDecoration(
            labelText: label.toUpperCase(),
            hintText: 'Ingresar $key...',
            prefixIcon: isNum
                ? const Icon(Icons.numbers, color: AppColors.textSecondary)
                : null,
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
          const Text(
            'Decisión Requerida',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Seleccione una de las opciones para continuar.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          if (_pasoActual?.siguientes != null)
            ..._pasoActual!.siguientes!.keys
                .map(
                  (opcion) => Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _isSubmitting
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: () => _submitDecision(opcion),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: Text(
                              opcion,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                  ),
                )
                ,
        ],
      );
    }

    // ACTIVIDAD with multi-route — show form + route selection buttons
    if (isMultiRoute) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Información y Selección',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Complete la información y seleccione la opción que corresponda.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildAIAssistantUI(),
          const SizedBox(height: 24),
          ..._schemaProperties.entries.map((entry) {
            final key = entry.key;
            final spec = entry.value;
            final label = spec['description'] ?? key;
            return _buildDynamicField(key, spec, label.toString());
          }),
          const SizedBox(height: 24),
          const Text(
            'Seleccione una opción:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ..._pasoActual!.siguientes!.keys
              .map(
                (opcion) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _isSubmitting
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () => _submitDecision(opcion),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: Text(
                            opcion,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                ),
              )
              ,
        ],
      );
    }

    // Normal ACTIVIDAD — form + submit button
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Requerimiento del Cliente',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Complete la siguiente información para que su trámite avance.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        _buildAIAssistantUI(),
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
              ),
      ],
    );
  }

  Widget _buildStepSelector() {
    if (_activeClientSteps.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REQUERIMIENTOS EN PARALELO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _activeClientSteps.map((paso) {
                final isSelected = _pasoActual?.id == paso.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      paso.nombrePaso,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceVariant,
                    side: BorderSide(
                      color: isSelected ? AppColors.primaryLight : AppColors.border,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _pasoActual = paso;
                          _parseSchema();
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAssistantUI() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Asistente IA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryLight)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatPromptController,
                  enabled: !_isAssisting,
                  decoration: const InputDecoration(
                    hintText: 'Describe cómo llenar el formulario',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isAssisting ? null : _solicitarAsistenciaChat,
                icon: _isAssisting 
                   ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                   : const Icon(Icons.send, color: AppColors.primaryLight),
                tooltip: 'Autocompletar',
              ),
              IconButton(
                onPressed: _isAssisting ? null : _toggleVoiceInput,
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: _isListening ? Colors.red : AppColors.textSecondary),
                tooltip: 'Usar Voz',
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_voiceStatus, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDone = _tramiteState.estadoGlobal == 'FINALIZADO';
    bool needsClientResponse =
        _pasoActual != null && _pasoActual!.departamentoId == null && !isDone;

    bool showInvoice =
        _tramiteState.invoiceUrl != null &&
        _tramiteState.invoiceUrl!.isNotEmpty &&
        [
          'PENDIENTE',
          'EN_PROCESO',
          'FINALIZADO',
        ].contains(_tramiteState.estadoGlobal);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento'),
        actions: [
          if (showInvoice)
            IconButton(
              icon: const Icon(Icons.receipt_long),
              tooltip: 'Ver Factura',
              onPressed: () async {
                final urlString = _tramiteState.invoiceUrl!;
                final url = Uri.parse(
                  urlString.startsWith('http')
                      ? urlString
                      : 'https://$urlString',
                );
                try {
                  final launched = await launchUrl(
                    url,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!launched && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No se pudo abrir el enlace'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al abrir el enlace')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      floatingActionButton: isDone
          ? FloatingActionButton(
              onPressed: () => _showResumenBottomSheet(context),
              backgroundColor: AppColors.primary,
              child: const Icon(
                Icons.help_outline_rounded,
                color: Colors.white,
                size: 28,
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Text(
                  'Progreso: ${_tramiteState.nombrePlantilla}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withOpacity(0.1)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDone ? Colors.green : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDone ? Icons.check_circle : Icons.hourglass_top,
                        color: isDone ? Colors.green : AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isDone
                              ? 'Trámite Completado'
                              : 'Esperando paso: ${_pasoActual?.nombrePaso ?? "Desconocido"}',
                          style: TextStyle(
                            color: isDone
                                ? Colors.green
                                : AppColors.primaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (needsClientResponse)
                  _buildStepSelector(),

                if (!isDone && !needsClientResponse)
                  const Padding(
                    padding: EdgeInsets.only(top: 24.0),
                    child: Text(
                      'Su trámite está siendo procesado por el departamento designado. Se le notificará al avanzar.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),

                if (needsClientResponse)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: _buildClientResponseWidget(),
                  ),
              ],
            ),
    );
  }

  Future<void> _uploadLiveFile(String filePath, String key, StateSetter setStateFile) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    
    setStateFile(() {
      _uploadProgress[key] = 0.0;
    });

    try {
      final fileName = filePath.split('/').last.split('\\').last;
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'campoKey': key,
        'pasoId': _pasoActual?.id ?? '',
      });

      final url = '${ApiService.baseUrl}/tramites/${_tramiteState.id}/documentos/upload-estatico';
      
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
        onSendProgress: (int sent, int total) {
          if (total > 0 && mounted) {
            setStateFile(() {
              _uploadProgress[key] = (sent / total * 100);
            });
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Documento subido correctamente'), backgroundColor: Colors.green),
           );
           // Clear progress securely via main state
           setState(() {
             _uploadProgress.remove(key);
           });
           // Refresh the entire state
           await _fetchDetails(); 
        }
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _uploadProgress.remove(key);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _downloadFile(String archivoId, String nombreOriginal) async {
    if (_isDownloading[archivoId] == true) return;
    
    setState(() {
      _isDownloading[archivoId] = true;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Descargando archivo...'), duration: Duration(seconds: 1)),
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');

      final url = '${ApiService.baseUrl}/documentos/$archivoId/descargar';
      
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$nombreOriginal';

      // Realizar la descarga directamente (evitamos un HEAD request que pueda dejar streams de S3 abiertos en el backend)
      await _dio.download(
        url,
        savePath,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          receiveTimeout: const Duration(seconds: 60),
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      await OpenFilex.open(savePath);

    } catch (e) {
      if (mounted) {
        String errorMsg = e.toString();
        if (errorMsg.contains('No route to host') || errorMsg.contains('SocketException')) {
          errorMsg = 'Error de red: No se pudo conectar al servidor (192.168.0.8). Verifique que está en la misma red WiFi y que la IP del PC no ha cambiado.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[archivoId] = false;
        });
      }
    }
  }

  void _mostrarHistorialBottomSheet(String key) {
    final historial = _historialMap[key] ?? [];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text('Historial de Versiones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                     IconButton(icon: const Icon(Icons.close, color: AppColors.textSecondary), onPressed: () => Navigator.pop(context)),
                   ]
                 ),
               ),
               const Divider(height: 1, color: AppColors.border),
               if (historial.isEmpty)
                 const Padding(padding: EdgeInsets.all(32), child: Text('No hay versiones anteriores', style: TextStyle(color: AppColors.textSecondary))),
               if (historial.isNotEmpty)
                 Expanded(
                   child: ListView.builder(
                     itemCount: historial.length,
                     itemBuilder: (context, i) {
                       final doc = historial[i];
                       return ListTile(
                          leading: const Icon(Icons.history, color: AppColors.textSecondary),
                          title: Text('Versión ${doc['version'] ?? '?'}', style: const TextStyle(color: AppColors.textPrimary)),
                          subtitle: Text(doc['nombreOriginal'] ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: IconButton(
                             icon: const Icon(Icons.download, color: AppColors.primaryLight),
                             onPressed: () {
                                if (doc['archivoId'] != null) {
                                   Navigator.pop(context);
                                   _downloadFile(doc['archivoId'], doc['nombreOriginal'] ?? 'documento_${doc['archivoId']}');
                                }
                             }
                          ),
                       );
                     }
                   )
                 )
            ]
          )
        );
      }
    );
  }

  void _showResumenBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResumenBottomSheet(tramiteId: _tramiteState.id),
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
      if (mounted) {
        setState(() {
          _resumen = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
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
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.primaryLight,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Resumen del Trámite',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.border, height: 1),
                // Content
                Expanded(
                  child: _loading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Generando resumen con IA...',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'No se pudo generar el resumen.',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        )
                      : ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Estado badge
                            _buildEstadoBadge(
                              _resumen!['estado'] ?? 'Completado',
                            ),
                            const SizedBox(height: 16),
                            // Resumen
                            Text(
                              _resumen!['resumen'] ?? '',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Pasos clave
                            if (_resumen!['pasosClave'] != null &&
                                (_resumen!['pasosClave'] as List)
                                    .isNotEmpty) ...[
                              const Text(
                                'Puntos Clave',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...(_resumen!['pasosClave'] as List).map(
                                (paso) => _buildPasoClave(paso),
                              ),
                              const SizedBox(height: 24),
                            ],
                            // Conclusión
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: AppColors.primaryLight,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _resumen!['conclusion'] ?? '',
                                      style: const TextStyle(
                                        color: AppColors.primaryLight,
                                        fontSize: 14,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoBadge(String estado) {
    Color bgColor;
    Color textColor;
    if (estado.toLowerCase().contains('aprobado')) {
      bgColor = Colors.green.withOpacity(0.15);
      textColor = Colors.green;
    } else if (estado.toLowerCase().contains('rechazado')) {
      bgColor = AppColors.error.withOpacity(0.15);
      textColor = AppColors.error;
    } else {
      bgColor = AppColors.info.withOpacity(0.15);
      textColor = AppColors.info;
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          estado,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paso['nombre'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  paso['resultado'] ?? '',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
