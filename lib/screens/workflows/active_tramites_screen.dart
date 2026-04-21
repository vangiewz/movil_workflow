import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/tramite_model.dart';
import '../../services/workflow_service.dart';
import 'package:go_router/go_router.dart';

class ActiveTramitesScreen extends StatefulWidget {
  const ActiveTramitesScreen({super.key});

  @override
  State<ActiveTramitesScreen> createState() => _ActiveTramitesScreenState();
}

class _ActiveTramitesScreenState extends State<ActiveTramitesScreen> {
  List<Tramite> _tramites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTramites();
  }

  Future<void> _loadTramites() async {
    try {
      final data = await WorkflowService.getActiveTramites();
      if (mounted) {
        setState(() {
          _tramites = data;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis Trámites')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tramites.isEmpty
              ? const Center(child: Text('No tienes trámites en curso o finalizados.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(24.0),
                  itemCount: _tramites.length,
                  itemBuilder: (context, index) {
                    final t = _tramites[index];
                    final isDone = t.estadoGlobal == 'FINALIZADO';
                    final colorStatus = isDone ? Colors.green : AppColors.primary;

                    return GestureDetector(
                      onTap: () {
                         context.push('/tramites/detail', extra: t);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colorStatus.withOpacity(0.5)),
                          boxShadow: !isDone ? [BoxShadow(color: AppColors.accentGlow, blurRadius: 6)] : [],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('ID: ${t.id?.substring(0, 8)}...', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                Text(t.estadoGlobal, style: TextStyle(color: colorStatus, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(t.nombrePlantilla, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (!isDone) 
                               Row(
                                 children: [
                                    const Icon(Icons.pending_actions, size: 16, color: AppColors.secondary),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('Trámite en curso. Toca para ver detalles.', style: const TextStyle(color: AppColors.textSecondary))),
                                 ],
                               ),
                            if (isDone)
                               const Row(
                                 children: [
                                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text('Completado orgánicamente.', style: TextStyle(color: Colors.green)),
                                 ],
                               )
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
