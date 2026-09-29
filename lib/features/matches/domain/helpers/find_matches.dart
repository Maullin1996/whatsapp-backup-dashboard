import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';

/// Cruza los números ganadores contra los registros de una jornada
/// (`image-review-domain`, regla 7): un registro coincide si su `numero`
/// iguala a alguno de [winningNumbers], carácter por carácter, después de
/// `trim` en ambos lados. Sin normalizar mayúsculas, sin quitar ceros a la
/// izquierda, sin comparación numérica — "0123" y "123" son distintos.
///
/// Devuelve TODOS los registrados que coinciden con ALGÚN ganador: si el
/// mismo número ganador coincide con registros de dos grupos distintos, los
/// dos salen (una entrada por registro, no por ganador).
List<MatchEntry> findMatches(
  List<String> winningNumbers,
  List<MatchEntry> registered,
) {
  final winners = winningNumbers.map((n) => n.trim()).toSet();
  return [
    for (final entry in registered)
      if (winners.contains(entry.numero.trim())) entry,
  ];
}
