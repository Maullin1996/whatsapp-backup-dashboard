import 'package:freezed_annotation/freezed_annotation.dart';

part 'comprobante.freezed.dart';

/// Un comprobante (boleto) dentro de una imagen. Es independiente de los
/// demás: nunca se agrupan ni se suman entre sí. El código no va aquí: es uno
/// por imagen (`ImageReviewForm.codigo`).
@freezed
abstract class Comprobante with _$Comprobante {
  const factory Comprobante({
    /// Se guardan como String para conservar ceros a la izquierda
    /// ("0123" != "123").
    required List<String> numeros,

    /// Pesos, sin decimales.
    required int total,

    /// Identificador de la lotería de este comprobante, de la lista cerrada
    /// (`lib/core/lotteries/lotteries.dart`); se guarda el identificador, no
    /// el nombre. Obligatoria al guardar (`validateImageReviewForm`, los dos
    /// roles). Sigue siendo `String?` porque un registro viejo trae texto
    /// libre o null: esos no coinciden con ningún ganador. Puede variar entre
    /// los boletos de una misma foto; no entra en la reconciliación.
    String? loteria,
  }) = _Comprobante;
}
