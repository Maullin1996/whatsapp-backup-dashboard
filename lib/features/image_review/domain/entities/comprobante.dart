import 'package:freezed_annotation/freezed_annotation.dart';

part 'comprobante.freezed.dart';

/// Un comprobante dentro de una imagen. Es independiente de los demás:
/// compartir [codigo] con otro comprobante no los agrupa ni los suma.
@freezed
abstract class Comprobante with _$Comprobante {
  const factory Comprobante({
    required String codigo,

    /// Se guardan como String para conservar ceros a la izquierda
    /// ("0123" != "123").
    required List<String> numeros,

    /// Pesos, sin decimales.
    required int total,
  }) = _Comprobante;
}
