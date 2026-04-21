import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/plantilla_workflow.dart';
import '../../services/workflow_service.dart';
import '../../services/draft_service.dart';
import 'package:go_router/go_router.dart';

class FormScreen extends StatefulWidget {
  final PlantillaWorkflow workflow;
  const FormScreen({super.key, required this.workflow});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isLoading = false;
  Map<String, dynamic> _schemaProperties = {};

  @override
  void initState() {
    super.initState();
    _parseSchema();
  }

  void _parseSchema() {
    final formJson = widget.workflow.formularioCliente;
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

  Future<void> _submitForm() async {
    // Validar Requeridos
    final formJson = widget.workflow.formularioCliente;
    final List<dynamic> authRequired = formJson != null && formJson['required'] != null ? formJson['required'] : [];

    for (final key in authRequired) {
      if (_controllers[key] != null && _controllers[key]!.text.trim().isEmpty) {
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
      await WorkflowService.createTramite(widget.workflow.id, formData);
      await DraftService.removePaidDraft(widget.workflow.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Trámite creado exitosamente!')));
        context.go('/home'); // Regresar al dashboard
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
              _controllers[key]!.text = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
            }
          },
        ),
      );
    } else {
      // String simple o Número
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
}
