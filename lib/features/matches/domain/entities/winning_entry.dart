import 'package:freezed_annotation/freezed_annotation.dart';

part 'winning_entry.freezed.dart';

/// Un número ganador con su lotería: una entrada de
/// `winning_numbers/{fecha}.entries` (la escribe la función puente). Un ganador
/// solo coincide con un número de la MISMA lotería (`findMatches`).
@freezed
abstract class WinningEntry with _$WinningEntry {
  const factory WinningEntry({
    /// Identificador de la lotería (clave de `lotteryKey`; ver
    /// `lib/core/lotteries/lotteries.dart`). Puede venir fuera de la lista o
    /// vacío (entrada sin slug): esa no coincide con nada.
    required String loteria,

    /// El número ganador, tal cual (conserva ceros a la izquierda).
    required String numero,
  }) = _WinningEntry;
}
