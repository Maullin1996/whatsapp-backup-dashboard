import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/role_group_summary.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_pesos.dart';

/// Icono de cada rol, compartido por la tarjeta y el detalle.
IconData summaryRoleIcon(ReviewRole rol) => switch (rol) {
  ReviewRole.revisor => Icons.fact_check_rounded,
  ReviewRole.sumador => Icons.calculate_rounded,
};

/// Tarjeta de un rol dentro de un grupo: arriba el total de lo que sumó, y
/// debajo las jornadas (las que ya registró, y en gris las que le faltan).
/// Tocarla abre el detalle por jornada ([onTap]).
class SummaryRoleCard extends StatelessWidget {
  final RoleGroupSummary summary;
  final VoidCallback onTap;

  const SummaryRoleCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final registradas = summary.registradas;
    final sinNada = registradas.isEmpty;

    return Material(
      color: AppColors.screenBackground.withValues(alpha: 0.5),
      borderRadius: AppRadius.tileAll,
      child: InkWell(
        borderRadius: AppRadius.tileAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.tileAll,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    summaryRoleIcon(summary.rol),
                    size: 18,
                    color: AppColors.accentTeal,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      summary.rol.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  sinNada ? '—' : formatPesos(summary.total),
                  style: textTheme.titleLarge
                      ?.merge(AppTypography.tabular)
                      .copyWith(
                        fontWeight: FontWeight.w800,
                        color: sinNada ? Colors.grey.shade500 : null,
                      ),
                ),
              ),
              Text(
                sinNada ? 'Sin registrar' : 'Total sumado',
                style: textTheme.bodySmall?.copyWith(
                  color: sinNada ? AppColors.warning : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final j in summary.jornadas)
                    _JornadaChip(
                      label: shortShiftName(j.summary.shift),
                      registrada: j.role.registrado,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Jornada del rol: verde con check si ya la registró; gris punteado si le
/// falta (sin alarmar: el detalle explica qué hace falta).
class _JornadaChip extends StatelessWidget {
  final String label;
  final bool registrada;

  const _JornadaChip({required this.label, required this.registrada});

  @override
  Widget build(BuildContext context) {
    final color = registrada ? AppColors.success : Colors.grey.shade600;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: registrada ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: AppRadius.pillAll,
        border: registrada ? null : Border.all(color: Colors.grey.shade400),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              registrada
                  ? Icons.check_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 2),
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
