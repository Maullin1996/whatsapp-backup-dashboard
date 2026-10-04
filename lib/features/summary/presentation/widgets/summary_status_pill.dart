import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_pesos.dart';

/// Texto, icono y color de un estado de jornada. Rojo solo para el descuadre
/// de dinero; ámbar para lo pendiente; verde para lo que cuadra.
(String, IconData, Color) summaryStatusStyle(JornadaEstado estado) =>
    switch (estado) {
      JornadaCuadra() => (
        'Cuadra',
        Icons.check_circle_rounded,
        AppColors.success,
      ),
      JornadaDescuadre(:final diferencia) => (
        'Descuadre de ${formatPesos(diferencia)}',
        Icons.warning_amber_rounded,
        AppColors.errorMessage,
      ),
      JornadaPendiente(:final faltan) => (
        faltan.length == 2
            ? 'Faltan Revisor y Sumador'
            : 'Falta ${faltan.single.label}',
        Icons.hourglass_top_rounded,
        AppColors.warning,
      ),
    };

/// Pastilla de estado (patrón de `ReviewStatusChip`: fondo al 12 % de alpha,
/// texto e icono del mismo color, radio pill).
class SummaryStatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const SummaryStatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  SummaryStatusPill.of(JornadaEstado estado, {Key? key})
    : this._fromStyle(summaryStatusStyle(estado), key: key);

  SummaryStatusPill._fromStyle((String, IconData, Color) style, {super.key})
    : label = style.$1,
      icon = style.$2,
      color = style.$3;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: AppSpacing.lg, color: color),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.badge.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
