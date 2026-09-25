import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/format_pesos.dart';

/// Vista de solo lectura de un registro ya guardado.
class ReviewReadOnlyView extends StatelessWidget {
  final ImageReviewRecord record;

  const ReviewReadOnlyView({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final comprobantes = record.form.comprobantes;
    final anotaciones = record.form.anotaciones;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Registro guardado',
                style: AppTypography.headerTitle(context),
              ),
            ),
            if (record.editado) const _EditedBadge(),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var i = 0; i < comprobantes.length; i++)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comprobante ${i + 1}',
                    style: AppTypography.headerTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Código: ${comprobantes[i].codigo}'),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final numero in comprobantes[i].numeros)
                        Chip(label: Text(numero)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Total: ${formatPesos(comprobantes[i].total)}'),
                ],
              ),
            ),
          ),
        if (anotaciones != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Anotaciones',
                    style: AppTypography.headerTitle(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(anotaciones),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _EditedBadge extends StatelessWidget {
  const _EditedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorMessage.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Text(
        'Editado',
        style: AppTypography.badge.copyWith(color: AppColors.errorMessage),
      ),
    );
  }
}
