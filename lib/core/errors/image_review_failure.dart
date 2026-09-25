import 'package:freezed_annotation/freezed_annotation.dart';

part 'image_review_failure.freezed.dart';

/// Errores de validación del formulario de revisión de imágenes.
/// [indice] es 1-based: coincide con el "Comprobante N" que ve el usuario.
@freezed
abstract class ImageReviewFailure with _$ImageReviewFailure {
  const factory ImageReviewFailure.sinComprobantes() = _SinComprobantes;
  const factory ImageReviewFailure.codigoVacio(int indice) = _CodigoVacio;
  const factory ImageReviewFailure.comprobanteSinNumeros(int indice) =
      _ComprobanteSinNumeros;
  const factory ImageReviewFailure.totalInvalido(int indice) = _TotalInvalido;
}

extension ImageReviewFailureMessageX on ImageReviewFailure {
  String get message => switch (this) {
    _SinComprobantes() => 'Agrega al menos un comprobante',
    _CodigoVacio(:final indice) => 'Comprobante $indice: ingresa el código',
    _ComprobanteSinNumeros(:final indice) =>
      'Comprobante $indice: agrega al menos un número',
    _TotalInvalido(:final indice) =>
      'Comprobante $indice: el total debe ser mayor que 0',
    ImageReviewFailure() => throw UnimplementedError(),
  };
}
