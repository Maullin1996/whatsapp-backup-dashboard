import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';

part 'day_matches.freezed.dart';

/// Coincidencias de un día, por jornada. Los reportes son diarios y no
/// acumulables (`image-review-domain`, regla 5): un `DayMatches` nunca se
/// combina con el de otro día, cada consulta es independiente.
@freezed
abstract class DayMatches with _$DayMatches {
  const DayMatches._();

  const factory DayMatches({
    /// Día consultado (`yyyy-MM-dd`).
    required String fechaJornada,
    required List<JornadaMatches> jornadas,
  }) = _DayMatches;

  /// Si alguna jornada del día tuvo al menos una coincidencia.
  bool get tieneGanador => jornadas.any((j) => j.matches.isNotEmpty);
}
