import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Tarjeta blanca con borde fino: cada bloque del panel (comprobante,
/// anotaciones) va en una, todas con el mismo padding.
class ReviewSectionCard extends StatelessWidget {
  final Widget child;

  const ReviewSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: child,
      ),
    );
  }
}

/// Cabecera de una tarjeta de comprobante: círculo con el número y el título;
/// a la derecha, [trailing] (la papelera en edición).
class ComprobanteHeader extends StatelessWidget {
  final int number;
  final Widget? trailing;

  const ComprobanteHeader({super.key, required this.number, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          key: ValueKey('comprobante-badge-$number'),
          radius: 14,
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
          child: Text(
            '$number',
            style: AppTypography.badge.copyWith(color: Colors.green.shade800),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text('Comprobante', style: AppTypography.headerTitle(context)),
        ),
        ?trailing,
      ],
    );
  }
}
