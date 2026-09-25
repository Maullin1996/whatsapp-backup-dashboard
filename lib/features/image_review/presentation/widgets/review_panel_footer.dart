import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/format_pesos.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Pie fijo del panel: resumen ("N comprobantes" / "Suma: $X"), el error de
/// guardado (si hay) y las acciones.
class ReviewPanelFooter extends StatelessWidget {
  final int comprobantesCount;

  /// Suma de los totales (los vacíos cuentan 0).
  final int sum;
  final Object? error;
  final Widget child;

  const ReviewPanelFooter({
    super.key,
    required this.comprobantesCount,
    required this.sum,
    required this.child,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    comprobantesCount == 1
                        ? '1 comprobante'
                        : '$comprobantesCount comprobantes',
                  ),
                ),
                Text(
                  'Suma: ${formatPesos(sum)}',
                  key: const ValueKey('footer-suma'),
                  style: AppTypography.tabular.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (error != null) ...[
              Text(
                mapFailureToMessage(error!),
                style: const TextStyle(color: AppColors.errorMessage),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
