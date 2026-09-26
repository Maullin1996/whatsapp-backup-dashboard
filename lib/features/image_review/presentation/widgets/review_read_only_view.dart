import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/format_pesos.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_section_card.dart';

/// Cuerpo de solo lectura de un registro guardado: las mismas tarjetas y el
/// mismo orden que el formulario (código, números, total), con texto estático.
/// El registro del Sumador no tiene números, así que no muestra ese bloque.
class ReviewReadOnlyView extends StatelessWidget {
  final ImageReviewRecord record;

  const ReviewReadOnlyView({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final comprobantes = record.form.comprobantes;
    final anotaciones = record.form.anotaciones;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < comprobantes.length; i++) ...[
            ReviewSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ComprobanteHeader(number: i + 1),
                  const SizedBox(height: AppSpacing.md),
                  _ReadField(
                    label: 'Código',
                    child: Text(
                      comprobantes[i].codigo,
                      style: AppTypography.tabular,
                    ),
                  ),
                  if (record.rol == ReviewRole.revisor) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ReadField(
                      label: 'Números · ${comprobantes[i].numeros.length}',
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final numero in comprobantes[i].numeros)
                            Chip(
                              label: Text(numero, style: AppTypography.tabular),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _ReadField(
                    label: 'Total',
                    child: Text(
                      formatPesos(comprobantes[i].total),
                      textAlign: TextAlign.end,
                      style: AppTypography.tabular.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (anotaciones != null)
            ReviewSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.sticky_note_2_rounded,
                        size: 20,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Anotaciones',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.headerTitle(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(anotaciones),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Etiqueta pequeña sobre un valor estático.
class _ReadField extends StatelessWidget {
  final String label;
  final Widget child;

  const _ReadField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTypography.timestamp(context)),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
