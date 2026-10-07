import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/role_group_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_role_card.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_status_pill.dart';

/// Un grupo en la lista del Resumen: su nombre con una sola pastilla de
/// estado (lo más urgente) y, debajo, las tarjetas del Revisor y del Sumador
/// lado a lado. [onOpenRole] recibe el rol de la tarjeta tocada.
class SummaryGroupTile extends StatelessWidget {
  final List<JornadaSummary> jornadas;
  final DateTime now;
  final ValueChanged<ReviewRole> onOpenRole;

  const SummaryGroupTile({
    super.key,
    required this.jornadas,
    required this.now,
    required this.onOpenRole,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupHeader(jornadas: jornadas),
            const SizedBox(height: AppSpacing.md),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final rol in ReviewRole.values) ...[
                    if (rol != ReviewRole.values.first)
                      const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: SummaryRoleCard(
                        summary: RoleGroupSummary.of(rol, jornadas, now),
                        onTap: () => onOpenRole(rol),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nombre del grupo y UNA pastilla con lo más grave de sus jornadas:
/// descuadre, si no pendiente, si no "Todo cuadra".
class _GroupHeader extends StatelessWidget {
  final List<JornadaSummary> jornadas;

  const _GroupHeader({required this.jornadas});

  static String _count(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';

  @override
  Widget build(BuildContext context) {
    var descuadres = 0, pendientes = 0;
    for (final j in jornadas) {
      switch (j.estado) {
        case JornadaDescuadre():
          descuadres++;
        case JornadaPendiente():
          pendientes++;
        case JornadaCuadra():
          break;
      }
    }

    final pill = descuadres > 0
        ? SummaryStatusPill(
            label: _count(descuadres, 'descuadre', 'descuadres'),
            icon: Icons.warning_amber_rounded,
            color: AppColors.errorMessage,
          )
        : pendientes > 0
        ? SummaryStatusPill(
            label: _count(pendientes, 'pendiente', 'pendientes'),
            icon: Icons.hourglass_top_rounded,
            color: AppColors.warning,
          )
        : const SummaryStatusPill(
            label: 'Todo cuadra',
            icon: Icons.check_circle_rounded,
            color: AppColors.success,
          );

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.groups_rounded,
              size: 20,
              color: AppColors.accentTeal,
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                jornadas.first.groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentTeal,
                ),
              ),
            ),
          ],
        ),
        pill,
      ],
    );
  }
}
