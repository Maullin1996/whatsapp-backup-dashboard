import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_status_chip.dart';

/// Encabezado del panel: título, subtítulo (jornada, hora y número de imagen
/// de la jornada) y chip de estado.
class ReviewPanelHeader extends StatelessWidget {
  final ImageReviewTarget target;
  final ReviewStatus status;

  const ReviewPanelHeader({
    super.key,
    required this.target,
    required this.status,
  });

  String get _subtitle => [
    target.shift,
    ?target.localTime,
    if (target.shiftImageIndex != null) 'Imagen #${target.shiftImageIndex}',
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Registro de la imagen',
                    style: AppTypography.headerTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.badge,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            ReviewStatusChip(status: status),
          ],
        ),
      ),
    );
  }
}
