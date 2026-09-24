import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';

part 'image_review_record.freezed.dart';

@freezed
abstract class ImageReviewRecord with _$ImageReviewRecord {
  const factory ImageReviewRecord({
    required String messageId,
    required String chatJid,
    required String shift,
    required ImageReviewForm form,
    required DateTime registradoEn,

    /// Email del usuario autenticado que diligenció el registro.
    required String registradoPor,

    /// false al crear. Quien re-guarda un registro existente (presentation)
    /// lo pone en true; el repositorio no lo decide.
    @Default(false) bool editado,
  }) = _ImageReviewRecord;
}
