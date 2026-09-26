import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

part 'image_review_record.freezed.dart';

/// Registro de una imagen. Hay uno por imagen y por rol: la clave es
/// (`messageId`, `rol`).
@freezed
abstract class ImageReviewRecord with _$ImageReviewRecord {
  const factory ImageReviewRecord({
    required String messageId,
    required String chatJid,
    required String shift,

    /// Rol con el que se diligenció (Revisor o Sumador).
    required ReviewRole rol,

    /// Referencia de la imagen en Storage (nunca la imagen ni una URL).
    required String storagePath,

    /// Día de la jornada (`yyyy-MM-dd`): la fecha del mensaje, no la de
    /// [registradoEn]. Ver `fechaJornadaDe`.
    required String fechaJornada,
    required ImageReviewForm form,
    required DateTime registradoEn,

    /// Email del usuario autenticado que diligenció el registro.
    required String registradoPor,

    /// false al crear. Quien re-guarda un registro existente (presentation)
    /// lo pone en true; el repositorio no lo decide.
    @Default(false) bool editado,

    /// Nace pendiente; al re-guardar vuelve a pendiente (lo decide
    /// presentation, igual que [editado]).
    @Default(EstadoSync.pendiente) EstadoSync estadoSync,
  }) = _ImageReviewRecord;
}
