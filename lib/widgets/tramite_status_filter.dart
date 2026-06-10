import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Widget pequeño y reutilizable que permite seleccionar el filtro de estado.
/// Renderiza chips horizontales para una selección visual más clara.
class TramiteStatusFilter extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const TramiteStatusFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const Map<String, String> options = {
    'ALL': 'Todos',
    'ESPERANDO_PAGO': 'Falta de pago',
    'PENDIENTE': 'Pendiente',
    'EN_PROGRESO': 'En progreso',
    'FINALIZADO': 'Finalizado',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 6),
              const Icon(Icons.filter_list, color: Colors.grey, size: 20),
              const SizedBox(width: 8),
              ...options.entries.map((e) {
                final key = e.key;
                final label = e.value;
                final selectedChip = key == selected;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(
                      label,
                      style: TextStyle(
                        color: selectedChip
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    selected: selectedChip,
                    onSelected: (_) => onChanged(key),
                    selectedColor: AppColors.primary,
                    backgroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: selectedChip
                            ? AppColors.primary
                            : Colors.transparent,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
