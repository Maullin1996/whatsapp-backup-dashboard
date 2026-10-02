import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';

part 'image_review_form.freezed.dart';

@freezed
abstract class ImageReviewForm with _$ImageReviewForm {
  const factory ImageReviewForm({
    /// Código de la imagen: UNO por foto, vale para todos sus comprobantes.
    /// Obligatorio al guardar (`validateImageReviewForm`); null solo en
    /// registros guardados antes de este campo, que no se pueden subir
    /// hasta volver a guardarlos.
    String? codigo,
    required List<Comprobante> comprobantes,

    /// Opcional, igual que `Comprobante.loteria`.
    String? anotaciones,
  }) = _ImageReviewForm;
}
