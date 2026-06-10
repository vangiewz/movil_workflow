import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/plantilla_workflow.dart';
import '../../services/workflow_service.dart';
import '../../services/draft_service.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class FormScreen extends StatefulWidget {
  final PlantillaWorkflow workflow;
  const FormScreen({super.key, required this.workflow});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, List<Map<String, TextEditingController>>> _gridControllers = {};
  final Map<String, String> _selectedFiles = {};
  bool _isLoading = false;
  Map<String, dynamic> _schemaProperties = {};

  bool _isAssisting = false;
  final TextEditingController _chatPromptController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceStatus = 'Pulsa "Usar Voz" y habla después de ver "Escuchando".';

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _parseSchema();
  }

  void _parseSchema() {
    final formJson = widget.workflow.formularioCliente;
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
    setState(() {
      _isAssisting = true;
      _voiceStatus = 'Procesando solicitud por $modo con IA...';
    });

    try {
      final response = await WorkflowService.asistirFormularioInicial(widget.workflow.id, modo, mensaje);
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

  Future<void> _submitForm() async {
    // Validar Requeridos
    final formJson = widget.workflow.formularioCliente;
    final List<dynamic> authRequired = formJson != null && formJson['required'] != null ? formJson['required'] : [];

    for (final key in authRequired) {
      final rawType = _schemaProperties[key]?['type']?.toString().toLowerCase();
      final rawFormat = _schemaProperties[key]?['format']?.toString().toLowerCase();
      final isFile = rawType == 'file' || rawFormat == 'file' || rawFormat == 'binary' || rawType == 'archivo' || rawType == 'archivo_estatico';
      if (isFile) {
        if (!_selectedFiles.containsKey(key)) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor sube el archivo: $key'), backgroundColor: AppColors.error));
          return;
        }
      } else if (rawType == 'array' || rawType == 'grid') {
        if (_gridControllers[key] == null || _gridControllers[key]!.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor agrega datos en: $key'), backgroundColor: AppColors.error));
          return;
        }
      } else if (_controllers[key] != null && _controllers[key]!.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Por favor llena el campo: $key'), backgroundColor: AppColors.error));
        return; // Detiene el flujo
      }
    }

    setState(() => _isLoading = true);

    // Mapear los controllers a un JSON
    final Map<String, dynamic> formData = {};
    _controllers.forEach((key, controller) {
      // Intentar forzar casteos estrictos si el schema lo pedía
      final propSpec = _schemaProperties[key];
      if (propSpec != null) {
        final rawType = propSpec['type']?.toString().toLowerCase();
        final rawFormat = propSpec['format']?.toString().toLowerCase();
        final isFile = rawType == 'file' || rawFormat == 'file' || rawFormat == 'binary' || rawType == 'archivo' || rawType == 'archivo_estatico';

        if (rawType == 'number' || rawType == 'integer') {
          formData[key] = num.tryParse(controller.text) ?? 0;
        } else if (rawType == 'boolean') {
          formData[key] = (controller.text == 'true');
        } else if (isFile) {
          // El archivo va en files, no en formData json
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
      final tramite = await WorkflowService.createTramite(widget.workflow.id, formData, files: _selectedFiles);
      await DraftService.removePaidDraft(widget.workflow.id);

      if (mounted) {
        if (tramite.estadoGlobal == 'ESPERANDO_PAGO') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trámite creado. Redirigiendo a pago...')));
          context.pushReplacement('/payment', extra: tramite);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Trámite creado exitosamente!')));
          context.go('/home'); // Regresar al dashboard
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Completar Requisitos')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Text('Formulario: ${widget.workflow.nombre}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_schemaProperties.isEmpty) 
                 const Text('No hay campos requeridos, puedes iniciar el trámite directamente.', style: TextStyle(color: AppColors.textSecondary)),
                 
              const SizedBox(height: 24),
              _buildAIAssistantUI(),
              const SizedBox(height: 16),

              // Renderizar dinámicamente los campos
              ..._schemaProperties.entries.map((entry) {
                final key = entry.key;
                final spec = entry.value;
                final label = spec['description'] ?? key;
                return _buildDynamicField(key, spec, label.toString());
              }),

              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Finalizar e Iniciar Trámite'),
              )
            ],
          ),
    );
  }

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
                activeThumbColor: AppColors.primaryLight,
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
              builder: (context, child) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: const ColorScheme.dark(
                      primary: AppColors.primary,
                      onPrimary: Colors.white,
                      surface: AppColors.surfaceVariant,
                      onSurface: Colors.white,
                    ),
                  ),
                  child: child!,
                );
              },
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
    } else if (type == 'file' || format == 'file' || format == 'binary' || type == 'archivo' || type == 'archivo_estatico') {
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
                      final file = result.files.single;
                      
                      final allowedFormats = spec['formatosPermitidos'] as List<dynamic>?;
                      if (allowedFormats != null && allowedFormats.isNotEmpty) {
                        final ext = '.${file.extension?.toLowerCase() ?? ''}';
                        if (!allowedFormats.contains(ext)) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Formato $ext no permitido. Use: ${allowedFormats.join(', ')}'), backgroundColor: AppColors.error));
                          }
                          return;
                        }
                      }
                      
                      final maxMb = spec['tamanoMaximoMB'];
                      if (maxMb != null) {
                        final maxSize = (maxMb as num).toInt() * 1024 * 1024;
                        if (file.size > maxSize) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('El archivo supera el límite de $maxMb MB.'), backgroundColor: AppColors.error));
                          }
                          return;
                        }
                      }
                      
                      setStateFile(() {
                        _selectedFiles[key] = file.path!;
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
      // String simple o Número
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
            prefixIcon: isNum ? const Icon(Icons.numbers, color: AppColors.textSecondary) : null,
          ),
        ),
      );
    }
  }
}
