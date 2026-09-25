import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/comprobante_card.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_read_only_view.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Panel del formulario del Revisor para una imagen.
///
/// Widget aislado: solo necesita el [target] (messageId, chatJid, shift) y un
/// ancho acotado por quien lo aloja. Todo el estado vive en los providers de
/// `image_review_providers.dart` (en memoria por ahora).
///
/// Modos: registro guardado (solo lectura + "Editar"), o formulario (nuevo, o
/// edición de un registro guardado).
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
      color: Colors.white,
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
    return Column(
      children: [
        Expanded(child: ReviewReadOnlyView(record: record)),
        _BottomBar(
          child: ElevatedButton(
            onPressed: () => ref
                .read(reviewDraftProvider(target.messageId).notifier)
                .startEditing(record),
            child: const Text('Editar'),
          ),
        ),
      ],
    );
  }
}

class _FormMode extends ConsumerWidget {
  final ImageReviewTarget target;

  /// Registro guardado al que corresponde este formulario (null si es nuevo).
  final ImageReviewRecord? record;

  const _FormMode({super.key, required this.target, required this.record});

  Future<void> _confirmDiscard(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(reviewDraftProvider(target.messageId).notifier);
    if (notifier.hasChangesAgainst(record!)) {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(reviewDraftProvider(target.messageId));
    final notifier = ref.read(reviewDraftProvider(target.messageId).notifier);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              for (var i = 0; i < draft.comprobantes.length; i++)
                ComprobanteCard(
                  key: ValueKey('${target.messageId}-${draft.comprobantes[i].id}'),
                  messageId: target.messageId,
                  number: i + 1,
                  draft: draft.comprobantes[i],
                  showErrors: draft.showErrors,
                  canRemove: draft.comprobantes.length > 1,
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: notifier.addComprobante,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Agregar comprobante'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _AnotacionesField(
                messageId: target.messageId,
                initialValue: draft.anotaciones,
              ),
            ],
          ),
        ),
        _BottomBar(
          error: draft.saveError,
          child: Row(
            children: [
              if (record != null) ...[
                TextButton(
                  onPressed: draft.isSaving
                      ? null
                      : () => _confirmDiscard(context, ref),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: draft.isSaving
                      ? null
                      : () => notifier.save(target),
                  child: draft.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Guardar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnotacionesField extends ConsumerStatefulWidget {
  final String messageId;
  final String initialValue;

  const _AnotacionesField({
    required this.messageId,
    required this.initialValue,
  });

  @override
  ConsumerState<_AnotacionesField> createState() => _AnotacionesFieldState();
}

class _AnotacionesFieldState extends ConsumerState<_AnotacionesField> {
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
    return TextField(
      key: const ValueKey('anotaciones'),
      controller: _controller,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        labelText: 'Anotaciones (opcional)',
        alignLabelWithHint: true,
      ),
      onChanged: (value) => ref
          .read(reviewDraftProvider(widget.messageId).notifier)
          .setAnotaciones(value),
    );
  }
}

/// Barra fija inferior con el error de guardado (si hay) y las acciones.
class _BottomBar extends StatelessWidget {
  final Widget child;
  final Object? error;

  const _BottomBar({required this.child, this.error});

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
