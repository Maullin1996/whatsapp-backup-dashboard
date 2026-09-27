import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_pesos.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';

/// Tarjeta de una jornada de un grupo: qué registró cada rol y si cuadra.
class JornadaSummaryCard extends StatelessWidget {
  final JornadaSummary summary;

  const JornadaSummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shortShiftName(summary.shift),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headerTitle(context),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: _StatusBadge(estado: summary.estado)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _RoleLine(rol: ReviewRole.revisor, summary: summary.revisor),
          const SizedBox(height: AppSpacing.xs),
          _RoleLine(rol: ReviewRole.sumador, summary: summary.sumador),
        ],
      ),
    );
  }
}

class _RoleLine extends StatelessWidget {
  final ReviewRole rol;
  final RoleSummary summary;

  const _RoleLine({required this.rol, required this.summary});

  static String _plural(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';

  @override
  Widget build(BuildContext context) {
    final detail = summary.registrado
        ? '${_plural(summary.cantidadImagenes, 'imagen', 'imágenes')} · '
              '${_plural(summary.cantidadTickets, 'ticket', 'tickets')} · '
              '${formatPesos(summary.totalSuma)}'
        : 'Sin registrar';

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '${rol.label}: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          TextSpan(
            text: detail,
            style: summary.registrado
                ? null
                : TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// Badge de estado (patrón de `ReviewStatusChip`: fondo al 12 % de alpha,
/// texto e icono del mismo color, radio pill).
class _StatusBadge extends StatelessWidget {
  final JornadaEstado estado;

  const _StatusBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (estado) {
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
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
