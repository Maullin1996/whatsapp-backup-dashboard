import 'package:whatsapp_monitor_viewer/core/lotteries/lotteries.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';

/// Cruza los ganadores contra los registros de una jornada
/// (`image-review-domain`, regla 7). Un ganador SOLO coincide con un número de
/// la MISMA lotería (`WinningEntry.loteria` contra `MatchEntry.loteria`, texto
/// exacto). Dentro de una lotería, todo se compara carácter por carácter
/// después de `trim` en ambos lados, sin normalizar mayúsculas ni quitar
/// ceros a la izquierda, y sin comparación numérica:
///
/// - Un registro de 4 caracteres coincide si es igual a un ganador de 4.
/// - Un registro de 3 coincide si es igual a las últimas 3 de un ganador de
///   4, o si es igual a un ganador de 3 (las dos vías valen a la vez:
///   "606" coincide con "606" y con "4606").
/// - Un registro de 2 coincide si es igual a las últimas 2 de un ganador de
///   4 o de 3 ("41" coincide con "5241"; "06" con "606").
/// - Un registro de 4 nunca coincide con un ganador de 3: "0606" no
///   coincide con "606".
/// - Un registro o un ganador de otra longitud se ignora, sin aviso.
/// - Un registro con lotería nula, vacía o fuera de la lista (`lotteries`)
///   no coincide con nada.
///
/// No valida que sean cifras (no está decidido). Devuelve TODOS los
/// registrados que coinciden con ALGÚN ganador de su lotería, una entrada por
/// registro y nunca dos veces, aunque coincida con varios ganadores: si el
/// mismo número ganador coincide con registros de dos grupos distintos, los
/// dos salen.
List<MatchEntry> findMatches(
  List<WinningEntry> winners,
  List<MatchEntry> registered,
) {
  // Por lotería: los ganadores de 4 cifras y las últimas 3 y 2 de los de 4 y 3.
  final byLoteria = <String, _Winners>{};
  for (final entry in winners) {
    final winner = entry.numero.trim();
    final bucket = byLoteria.putIfAbsent(entry.loteria, _Winners.new);
    if (winner.length == 4) {
      bucket.fourDigit.add(winner);
      bucket.threeDigit.add(winner.substring(1));
      bucket.twoDigit.add(winner.substring(2));
    } else if (winner.length == 3) {
      bucket.threeDigit.add(winner);
      bucket.twoDigit.add(winner.substring(1));
    }
  }

  bool matches(MatchEntry entry) {
    final loteria = entry.loteria;
    if (!isKnownLoteria(loteria)) return false;
    final bucket = byLoteria[loteria];
    if (bucket == null) return false;
    final numero = entry.numero.trim();
    return switch (numero.length) {
      4 => bucket.fourDigit.contains(numero),
      3 => bucket.threeDigit.contains(numero),
      2 => bucket.twoDigit.contains(numero),
      _ => false,
    };
  }

  return [
    for (final entry in registered)
      if (matches(entry)) entry,
  ];
}

class _Winners {
  final fourDigit = <String>{};
  final threeDigit = <String>{};
  final twoDigit = <String>{};
}

/// Los números COMPLETOS de la lotería con los que coincidió [entry] (el
/// número que anotó el Revisor puede ser de 2 o 3 cifras y el ganador de 4:
/// aquí sale el de 4, para no tener que buscarlo aparte).
///
/// Misma regla que [findMatches] (misma lotería, `trim`, sin normalizar): un
/// ganador de 3 o 4 cifras coincide si termina igual que el número registrado
/// de 2, 3 o 4 cifras y no es más corto que él. Primero los de más cifras y
/// sin repetir; vacío si [entry] no coincide con ninguno.
List<String> winningNumbersFor(List<WinningEntry> winners, MatchEntry entry) {
  final loteria = entry.loteria;
  if (!isKnownLoteria(loteria)) return const [];
  final numero = entry.numero.trim();
  if (numero.length < 2 || numero.length > 4) return const [];

  final found = <String>{};
  for (final winner in winners) {
    if (winner.loteria != loteria) continue;
    final full = winner.numero.trim();
    if (full.length != 3 && full.length != 4) continue;
    if (full.length >= numero.length && full.endsWith(numero)) found.add(full);
  }
  return found.toList()..sort((a, b) {
    final byLength = b.length.compareTo(a.length);
    return byLength != 0 ? byLength : a.compareTo(b);
  });
}
