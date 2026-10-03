import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';

/// Cruza los números ganadores contra los registros de una jornada
/// (`image-review-domain`, regla 7). Todo se compara carácter por carácter
/// después de `trim` en ambos lados, sin normalizar mayúsculas ni quitar
/// ceros a la izquierda, y sin comparación numérica:
///
/// - Un registro de 4 caracteres coincide si es igual a un ganador de 4.
/// - Un registro de 3 coincide si es igual a las últimas 3 de un ganador de
///   4, o si es igual a un ganador de 3 (las dos vías valen a la vez:
///   "606" coincide con "606" y con "4606").
/// - Un ganador de 3 solo se compara con registros de 3: "0606" nunca
///   coincide con "606".
/// - Un registro o un ganador de otra longitud se ignora, sin aviso.
///
/// No valida que sean cifras (no está decidido). Devuelve TODOS los
/// registrados que coinciden con ALGÚN ganador, una entrada por registro y
/// nunca dos veces, aunque coincida con varios ganadores: si el mismo número
/// ganador coincide con registros de dos grupos distintos, los dos salen.
List<MatchEntry> findMatches(
  List<String> winningNumbers,
  List<MatchEntry> registered,
) {
  final fourDigit = <String>{};
  final threeDigit = <String>{};
  for (final raw in winningNumbers) {
    final winner = raw.trim();
    if (winner.length == 4) {
      fourDigit.add(winner);
      threeDigit.add(winner.substring(1));
    } else if (winner.length == 3) {
      threeDigit.add(winner);
    }
  }

  bool matches(String raw) {
    final numero = raw.trim();
    return switch (numero.length) {
      4 => fourDigit.contains(numero),
      3 => threeDigit.contains(numero),
      _ => false,
    };
  }

  return [
    for (final entry in registered)
      if (matches(entry.numero)) entry,
  ];
}
