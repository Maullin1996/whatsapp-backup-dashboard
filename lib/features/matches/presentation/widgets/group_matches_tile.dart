import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/group_matches.dart';

/// Tarjeta de un grupo en la lista de Coincidencias: su nombre y cuántos
/// ganadores tuvo. Tocarla abre el detalle ([onTap]).
class GroupMatchesTile extends StatelessWidget {
  final GroupMatches group;
  final VoidCallback onTap;

  const GroupMatchesTile({super.key, required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final winners = group.winners;
    final color = winners == 0 ? Colors.grey.shade600 : AppColors.success;

    return Material(
      color: Colors.white,
      borderRadius: AppRadius.cardAll,
      child: InkWell(
        borderRadius: AppRadius.cardAll,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                size: 24,
                color: AppColors.accentTeal,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  group.groupName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              DecoratedBox(
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
                      Icon(
                        Icons.emoji_events_rounded,
                        size: AppSpacing.lg,
                        color: color,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        winners == 1 ? '1 ganador' : '$winners ganadores',
                        style: AppTypography.badge.copyWith(color: color),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade600),
            ],
          ),
        ),
      ),
    );
  }
}
