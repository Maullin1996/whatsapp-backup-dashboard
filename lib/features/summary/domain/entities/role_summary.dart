import 'package:freezed_annotation/freezed_annotation.dart';

part 'role_summary.freezed.dart';

/// Lo que registró un rol (Revisor o Sumador) en una jornada de un grupo.
@freezed
abstract class RoleSummary with _$RoleSummary {
  const RoleSummary._();

  const factory RoleSummary({
    /// false si ese rol todavía no registró nada en la jornada (los demás
    /// campos van en 0).
    required bool registrado,
    required int cantidadImagenes,
    required int cantidadTickets,

    /// Suma de los totales de todos sus comprobantes, en pesos.
    required int totalSuma,
  }) = _RoleSummary;

  /// El rol no registró nada.
  static const sinRegistrar = RoleSummary(
    registrado: false,
    cantidadImagenes: 0,
    cantidadTickets: 0,
    totalSuma: 0,
  );
}
