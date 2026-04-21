import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/plantilla_workflow.dart';
import '../../services/workflow_service.dart';
import 'package:go_router/go_router.dart';

class TramiteListScreen extends StatefulWidget {
  const TramiteListScreen({super.key});

  @override
  State<TramiteListScreen> createState() => _TramiteListScreenState();
}

class _TramiteListScreenState extends State<TramiteListScreen> {
  List<PlantillaWorkflow> _plantillas = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  Future<void> _loadWorkflows() async {
    try {
      final data = await WorkflowService.getWorkflows();
      if (mounted) {
        setState(() {
          _plantillas = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    }
  }

  void _onWorkflowSelected(PlantillaWorkflow workflow) {
    // Navigate to payment or detail page
    context.push('/payment', extra: workflow);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operación de Trámites')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _plantillas.isEmpty 
            ? const Center(child: Text('No hay trámites disponibles.'))
            : ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: _plantillas.length,
              itemBuilder: (context, index) {
                final wf = _plantillas[index];
                final bool requierePago = wf.costoBase > 0;

                return GestureDetector(
                  onTap: () => _onWorkflowSelected(wf),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: requierePago ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 4)] : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(wf.categoria, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                            requierePago 
                              ? Text('\$${wf.costoBase} USDT', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                              : const Text('Gratuito', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(wf.nombre, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(wf.descripcion, style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
