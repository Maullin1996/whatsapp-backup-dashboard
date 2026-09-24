import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';

part 'image_review_form.freezed.dart';

@freezed
abstract class ImageReviewForm with _$ImageReviewForm {
  const factory ImageReviewForm({
    required List<Comprobante> comprobantes,

    /// Único campo opcional del formulario.
    String? anotaciones,
  }) = _ImageReviewForm;
}
