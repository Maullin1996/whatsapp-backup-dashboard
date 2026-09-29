import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';

part 'jornada_matches.freezed.dart';

/// Coincidencias de una jornada: los números ganadores de esa jornada y
/// cuáles de ellos coincidieron con algún registro (ver `findMatches`).
///
/// Agrupado por jornada, nunca combinado con otras (`image-review-domain`,
/// regla 4): no existe un total ni una lista "del día completo" en este
/// nivel — eso vive un nivel arriba, en `DayMatches.jornadas`.
@freezed
abstract class JornadaMatches with _$JornadaMatches {
  const factory JornadaMatches({
    /// Etiqueta larga en español, igual que `Message.shift`.
    required String shift,

    /// Números ganadores de esta jornada. Vacía si esa jornada no tuvo
    /// ganadores.
    required List<String> winningNumbers,

    /// Coincidencias encontradas en esta jornada (puede ser más de una si el
    /// mismo número ganador coincide con registros de distintos grupos).
    required List<MatchEntry> matches,
  }) = _JornadaMatches;
}
