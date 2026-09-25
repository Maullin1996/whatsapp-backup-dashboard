import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Estado del registro de la imagen que se ve en el encabezado del panel.
enum ReviewStatus {
  /// No hay registro guardado.
  unsaved('Sin guardar', AppColors.warning),

  /// Registro guardado, nunca editado.
  saved('Guardado', AppColors.success),

  /// Registro guardado y editado después.
  edited('Editado', AppColors.errorMessage),

  /// Formulario abierto para editar un registro guardado.
  editing('Editando', AppColors.accentTeal);

  const ReviewStatus(this.label, this.color);

  final String label;
  final Color color;
}

/// Badge de [ReviewStatus] (patrón de ui-design: fondo al 12 % de alpha, texto
/// del mismo color, radio pill).
class ReviewStatusChip extends StatelessWidget {
  final ReviewStatus status;

  const ReviewStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          status.label,
          style: AppTypography.badge.copyWith(color: status.color),
        ),
      ),
    );
  }
}
