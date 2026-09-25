import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/comprobante_card.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/dashed_border_button.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_panel_footer.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_panel_header.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_read_only_view.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_section_card.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_status_chip.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Panel del formulario del Revisor para una imagen.
///
/// Widget aislado: solo necesita el [target] (messageId, chatJid, shift) y un
/// ancho acotado por quien lo aloja. Todo el estado vive en los providers de
/// `image_review_providers.dart` (en memoria por ahora).
///
/// Estructura: encabezado (estado del registro), cuerpo con scroll y pie fijo
/// (resumen y acciones). Modos: registro guardado (solo lectura + "Editar"), o
/// formulario (nuevo, o edición de un registro guardado).
class ImageReviewPanel extends ConsumerWidget {
  final ImageReviewTarget target;

  const ImageReviewPanel({super.key, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedRecordProvider(target.messageId));
    final isEditing = ref.watch(
      reviewDraftProvider(target.messageId).select((s) => s.isEditing),
    );

    return ColoredBox(
      color: AppColors.screenBackground,
      child: saved.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              mapFailureToMessage(error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (record) => record != null && !isEditing
            ? _ReadOnlyMode(
                key: ValueKey('read-${target.messageId}'),
                target: target,
                record: record,
              )
            : _FormMode(
                key: ValueKey('form-${target.messageId}'),
                target: target,
                record: record,
              ),
      ),
    );
  }
}

class _ReadOnlyMode extends ConsumerWidget {
  final ImageReviewTarget target;
  final ImageReviewRecord record;

  const _ReadOnlyMode({super.key, required this.target, required this.record});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comprobantes = record.form.comprobantes;

    return Column(
      children: [
        ReviewPanelHeader(
          target: target,
          status: record.editado ? ReviewStatus.edited : ReviewStatus.saved,
        ),
        Expanded(child: ReviewReadOnlyView(record: record)),
        ReviewPanelFooter(
          comprobantesCount: comprobantes.length,
          sum: comprobantes.fold(0, (sum, c) => sum + c.total),
          child: ElevatedButton(
            onPressed: () => ref
                .read(reviewDraftProvider(target.messageId).notifier)
                .startEditing(record),
            child: const _ButtonLabel(icon: Icons.edit_rounded, text: 'Editar'),
          ),
        ),
      ],
    );
  }
}

class _FormMode extends ConsumerStatefulWidget {
  final ImageReviewTarget target;

  /// Registro guardado al que corresponde este formulario (null si es nuevo).
  final ImageReviewRecord? record;

  const _FormMode({super.key, required this.target, required this.record});

  @override
  ConsumerState<_FormMode> createState() => _FormModeState();
}

class _FormModeState extends ConsumerState<_FormMode> {
  /// Comprobantes que ya existían: solo los que se agregan después reciben
  /// scroll y foco al crearse.
  late final Set<int> _seenIds = {
    for (final c
        in ref.read(reviewDraftProvider(widget.target.messageId)).comprobantes)
      c.id,
  };

  String get _messageId => widget.target.messageId;

  Future<void> _confirmDiscard() async {
    final notifier = ref.read(reviewDraftProvider(_messageId).notifier);
    if (notifier.hasChangesAgainst(widget.record!)) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('¿Descartar cambios?'),
          content: const Text('Los cambios sin guardar se perderán.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Seguir editando'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorMessage,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (discard != true) return;
    }
    notifier.cancelEditing();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reviewDraftProvider(_messageId));
    final notifier = ref.read(reviewDraftProvider(_messageId).notifier);
    final record = widget.record;

    final newIds = {
      for (final c in draft.comprobantes)
        if (!_seenIds.contains(c.id)) c.id,
    };
    _seenIds.addAll(newIds);

    return Column(
      children: [
        ReviewPanelHeader(
          target: widget.target,
          status: record == null ? ReviewStatus.unsaved : ReviewStatus.editing,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < draft.comprobantes.length; i++) ...[
                  ComprobanteCard(
                    key: ValueKey('$_messageId-${draft.comprobantes[i].id}'),
                    messageId: _messageId,
                    number: i + 1,
                    draft: draft.comprobantes[i],
                    showErrors: draft.showErrors,
                    canRemove: draft.comprobantes.length > 1,
                    focusOnCreate: newIds.contains(draft.comprobantes[i].id),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                DashedBorderButton(
                  label: 'Agregar comprobante',
                  icon: Icons.add_rounded,
                  onPressed: notifier.addComprobante,
                ),
                const SizedBox(height: AppSpacing.md),
                _AnotacionesCard(
                  messageId: _messageId,
                  initialValue: draft.anotaciones,
                ),
              ],
            ),
          ),
        ),
        ReviewPanelFooter(
          comprobantesCount: draft.comprobantes.length,
          sum: draft.comprobantes.fold(0, (sum, c) => sum + c.totalValue),
          error: draft.saveError,
          child: Row(
            children: [
              if (record != null) ...[
                TextButton(
                  onPressed: draft.isSaving ? null : _confirmDiscard,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: draft.isSaving
                      ? null
                      : () => notifier.save(widget.target),
                  child: draft.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const _ButtonLabel(
                          icon: Icons.check_rounded,
                          text: 'Guardar',
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Icono + texto de un botón de acción. Se arma a mano (y no con
/// `ElevatedButton.icon`) para que el botón siga siendo un `ElevatedButton`.
class _ButtonLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ButtonLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Text(text),
      ],
    );
  }
}

class _AnotacionesCard extends ConsumerStatefulWidget {
  final String messageId;
  final String initialValue;

  const _AnotacionesCard({required this.messageId, required this.initialValue});

  @override
  ConsumerState<_AnotacionesCard> createState() => _AnotacionesCardState();
}

class _AnotacionesCardState extends ConsumerState<_AnotacionesCard> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReviewSectionCard(
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
                  'Anotaciones (opcional)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headerTitle(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            key: const ValueKey('anotaciones'),
            controller: _controller,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'El número del comprobante 2 no se lee bien',
            ),
            onChanged: (value) => ref
                .read(reviewDraftProvider(widget.messageId).notifier)
                .setAnotaciones(value),
          ),
        ],
      ),
    );
  }
}
