import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/helpers/validate_image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/pending_uploads_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_state.dart';

class ReviewDraftNotifier extends Notifier<ReviewDraftState> {
  ReviewDraftNotifier(this.key);

  /// Imagen y rol de este borrador.
  final ReviewKey key;

  String get messageId => key.messageId;

  @override
  ReviewDraftState build() {
    // El borrador (solo en memoria) se reinicia al cambiar de usuario. Lo ya
    // guardado NO se pierde: vive en el almacenamiento local de cada uid.
    ref.watch(reviewerUidProvider);
    return ReviewDraftState.empty();
  }

  void _updateComprobante(
    int id,
    ComprobanteDraft Function(ComprobanteDraft) update,
  ) {
    state = state.copyWith(
      comprobantes: [
        for (final c in state.comprobantes) c.id == id ? update(c) : c,
      ],
    );
  }

  // ── Comprobantes ─────────────────────────────

  void addComprobante() {
    state = state.copyWith(
      comprobantes: [
        ...state.comprobantes,
        ComprobanteDraft(id: state.nextId),
      ],
      nextId: state.nextId + 1,
    );
  }

  /// Siempre queda al menos un comprobante.
  void removeComprobante(int id) {
    if (state.comprobantes.length <= 1) return;
    state = state.copyWith(
      comprobantes: [
        for (final c in state.comprobantes)
          if (c.id != id) c,
      ],
    );
  }

  void setCodigo(int id, String value) =>
      _updateComprobante(id, (c) => c.copyWith(codigo: value));

  void setTotal(int id, String digits) =>
      _updateComprobante(id, (c) => c.copyWith(total: digits));

  // ── Números ──────────────────────────────────

  void setNumeroPendiente(int id, String value) =>
      _updateComprobante(id, (c) => c.copyWith(numeroPendiente: value));

  /// Convierte el texto pendiente en un número (con trim, sin vacíos).
  void addNumero(int id) => _updateComprobante(id, _commitPending);

  void removeNumero(int id, int index) {
    _updateComprobante(
      id,
      (c) => c.copyWith(
        numeros: [
          for (var i = 0; i < c.numeros.length; i++)
            if (i != index) c.numeros[i],
        ],
      ),
    );
  }

  ComprobanteDraft _commitPending(ComprobanteDraft c) {
    final value = c.numeroPendiente.trim();
    if (value.isEmpty) return c.copyWith(numeroPendiente: '');
    return c.copyWith(numeros: [...c.numeros, value], numeroPendiente: '');
  }

  void setAnotaciones(String value) =>
      state = state.copyWith(anotaciones: value);

  // ── Edición de un registro existente ─────────

  void startEditing(ImageReviewRecord record) {
    state = ReviewDraftState.fromRecord(record);
  }

  /// Descarta el borrador y vuelve a la vista de solo lectura.
  void cancelEditing() {
    state = ReviewDraftState.empty();
  }

  bool hasChangesAgainst(ImageReviewRecord record) {
    if (state.comprobantes.any((c) => c.numeroPendiente.trim().isNotEmpty)) {
      return true;
    }
    return state.toForm() != record.form;
  }

  // ── Guardar ──────────────────────────────────

  Future<void> save(ImageReviewTarget target) async {
    if (state.isSaving) return;

    // Un número tipeado pero sin Enter/"+" no se debe perder en silencio.
    state = state.copyWith(
      comprobantes: [for (final c in state.comprobantes) _commitPending(c)],
    );

    final validation = validateImageReviewForm(state.toForm(), key.rol);
    final form = validation.fold((failure) {
      state = state.copyWith(showErrors: true, saveError: failure);
      return null;
    }, (valid) => valid);
    if (form == null) return;

    final email = ref.read(reviewerEmailProvider);
    if (email == null) {
      state = state.copyWith(
        showErrors: true,
        saveError: const Failure.unauthorized(),
      );
      return;
    }

    state = state.copyWith(isSaving: true, saveError: null);
    final repository = ref.read(imageReviewRepositoryProvider);

    final existing = await repository.getByMessageId(messageId, key.rol);
    if (!ref.mounted) return;
    final previous = existing.fold((_) => null, (record) => record);

    final record = ImageReviewRecord(
      messageId: messageId,
      chatJid: target.chatJid,
      shift: target.shift,
      rol: key.rol,
      storagePath: target.storagePath,
      fechaJornada: target.fechaJornada,
      form: form,
      registradoEn: DateTime.now(),
      registradoPor: email,
      // Lo deciden presentation, no el repositorio: re-guardar un registro
      // existente lo marca editado, y (nuevo o re-guardado, aunque estuviera
      // sincronizado) siempre queda pendiente: habrá que volver a subirlo.
      editado: previous != null,
      estadoSync: EstadoSync.pendiente,
    );

    final saved = await repository.save(record);
    if (!ref.mounted) return;

    saved.fold(
      (failure) => state = state.copyWith(isSaving: false, saveError: failure),
      (_) {
        ref.invalidate(savedRecordProvider(key));
        ref.invalidate(pendingUploadsProvider);
        state = state.copyWith(
          isSaving: false,
          isEditing: false,
          showErrors: false,
          saveError: null,
        );
      },
    );
  }
}
