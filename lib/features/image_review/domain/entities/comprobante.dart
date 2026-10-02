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

    /// Dónde se compró el boleto: texto libre, opcional (null si quedó
    /// vacío). Puede variar entre los boletos de una misma foto. No tiene
    /// relación con las loterías de los números ganadores ni entra en la
    /// reconciliación.
    String? loteria,
  }) = _Comprobante;
}
