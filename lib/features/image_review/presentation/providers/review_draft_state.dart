import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';

part 'review_draft_state.freezed.dart';

/// Comprobante tal como se está editando: los campos son texto crudo de los
/// inputs. [id] es estable durante la sesión del borrador (sirve de key).
@freezed
abstract class ComprobanteDraft with _$ComprobanteDraft {
  const ComprobanteDraft._();

  const factory ComprobanteDraft({
    required int id,
    @Default('') String codigo,
    @Default([]) List<String> numeros,

    /// Texto tipeado en el campo de número que aún no se agregó como chip.
    @Default('') String numeroPendiente,

    /// Solo dígitos (el input aplica `digitsOnly`).
    @Default('') String total,
  }) = _ComprobanteDraft;

  bool get hasData =>
      codigo.trim().isNotEmpty ||
      numeros.isNotEmpty ||
      numeroPendiente.trim().isNotEmpty ||
      total.isNotEmpty;

  int get totalValue => int.tryParse(total) ?? 0;
}

@freezed
abstract class ReviewDraftState with _$ReviewDraftState {
  const ReviewDraftState._();

  const factory ReviewDraftState({
    required List<ComprobanteDraft> comprobantes,
    @Default('') String anotaciones,
    @Default(1) int nextId,

    /// true mientras se edita un registro ya guardado.
    @Default(false) bool isEditing,

    /// true tras el primer intento fallido de guardar: activa los errores
    /// inline por campo.
    @Default(false) bool showErrors,
    @Default(false) bool isSaving,

    /// `ImageReviewFailure` (validación) o `Failure` (guardado).
    Object? saveError,
  }) = _ReviewDraftState;

  /// Borrador nuevo: un comprobante vacío ya agregado.
  factory ReviewDraftState.empty() =>
      const ReviewDraftState(comprobantes: [ComprobanteDraft(id: 0)]);

  /// Borrador para "Editar": copia del registro guardado.
  factory ReviewDraftState.fromRecord(ImageReviewRecord record) {
    final comprobantes = record.form.comprobantes;
    return ReviewDraftState(
      comprobantes: [
        for (var i = 0; i < comprobantes.length; i++)
          ComprobanteDraft(
            id: i,
            codigo: comprobantes[i].codigo,
            numeros: comprobantes[i].numeros,
            total: comprobantes[i].total.toString(),
          ),
      ],
      anotaciones: record.form.anotaciones ?? '',
      nextId: comprobantes.length,
      isEditing: true,
    );
  }

  /// Convierte el borrador en el formulario del dominio (sin validar).
  ImageReviewForm toForm() {
    final notes = anotaciones.trim();
    return ImageReviewForm(
      comprobantes: [
        for (final c in comprobantes)
          Comprobante(
            codigo: c.codigo.trim(),
            numeros: c.numeros,
            total: c.totalValue,
          ),
      ],
      anotaciones: notes.isEmpty ? null : notes,
    );
  }
}
