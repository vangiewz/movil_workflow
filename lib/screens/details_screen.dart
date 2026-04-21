import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/item_model.dart';
import '../widgets/custom_app_bar.dart';

/// Pantalla de detalles de un item
/// Patrón: Recibe parámetros via constructor
class DetailsScreen extends StatelessWidget {
  final int itemId;
  final ItemModel? item;

  const DetailsScreen({super.key, required this.itemId, this.item});

  @override
  Widget build(BuildContext context) {
    // Si no hay item, mostrar un placeholder
    final displayItem =
        item ??
        ItemModel(
          id: itemId,
          title: 'Elemento #$itemId',
          description: 'Descripción del elemento',
          category: 'General',
          createdAt: DateTime.now(),
        );

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Detalles',
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(Icons.article, size: 80, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            // Título
            Text(
              displayItem.title,
              style: Theme.of(context).textTheme.displaySmall,
            ),
            const SizedBox(height: 8),
            // Categoría
            Chip(
              label: Text(displayItem.category),
              backgroundColor: AppColors.secondary.withOpacity(0.2),
            ),
            const SizedBox(height: 24),
            // Descripción
            Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              displayItem.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            // Información adicional
            _buildInfoSection(context, 'Información', [
              _InfoRow(label: 'ID', value: displayItem.id.toString()),
              _InfoRow(
                label: 'Creado',
                value:
                    '${displayItem.createdAt.day}/${displayItem.createdAt.month}/${displayItem.createdAt.year}',
              ),
              _InfoRow(label: 'Categoría', value: displayItem.category),
            ]),
            const SizedBox(height: 32),
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Elemento guardado')),
                      );
                    },
                    icon: const Icon(Icons.favorite_outline),
                    label: const Text('Guardar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Compartiendo...')),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget para construir sección de información
  Widget _buildInfoSection(
    BuildContext context,
    String title,
    List<_InfoRow> rows,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: List.generate(
              rows.length,
              (index) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          rows[index].label,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          rows[index].value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                  if (index < rows.length - 1)
                    Divider(
                      height: 1,
                      color: AppColors.border,
                      indent: 12,
                      endIndent: 12,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Modelo simple para filas de información
class _InfoRow {
  final String label;
  final String value;

  _InfoRow({required this.label, required this.value});
}
