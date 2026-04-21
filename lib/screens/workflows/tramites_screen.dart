import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import 'package:go_router/go_router.dart';

class TramitesScreen extends StatelessWidget {
  const TramitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operación de Trámites')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Qué deseas hacer hoy?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              title: 'Iniciar un Trámite Nuevo',
              description: 'Explora nuestro catálogo de servicios e inicia una solicitud de inmediato.',
              icon: Icons.add_circle_outline,
              color: AppColors.primary,
              route: '/tramites/list',
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: 'Seguir Estado de Trámites',
              description: 'Monitorea el progreso de tus trámites activos y responde los requerimientos.',
              icon: Icons.track_changes,
              color: AppColors.secondary,
              route: '/tramites/active',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required String description, required IconData icon, required Color color, required String route}) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary)
          ],
        ),
      ),
    );
  }
}
