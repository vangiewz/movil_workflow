import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withAlpha(20), blurRadius: 40)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.maps_home_work_outlined, size: 48, color: AppColors.primaryLight),
                  const SizedBox(height: 16),
                  Text(
                    '¡Bienvenido a\nWorkflow App!',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Gestiona, visualiza e inicia tus trámites corporativos desde cualquier lugar.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            Text('¿Qué puedes hacer aquí?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            
            _buildFeatureRow(Icons.rocket_launch_outlined, 'Iniciar Trámites', 'Inicia flujos pagando con criptomonedas y rellenando el formulario inicial.'),
            _buildFeatureRow(Icons.timeline_outlined, 'Seguir progreso', 'Revisa en qué paso exacto va tu trámite y quién lo tiene a cargo.'),
            _buildFeatureRow(Icons.manage_accounts_outlined, 'Ajustar perfil', 'Actualiza tus datos de contacto y contraseñas de forma segura.'),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Icon(icon, color: AppColors.primaryLight, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
