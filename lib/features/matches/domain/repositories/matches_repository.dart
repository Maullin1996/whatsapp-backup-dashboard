import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';

abstract class MatchesRepository {
  /// Coincidencias del día [date] (solo cuenta el día, no la hora), por
  /// jornada. Los reportes son diarios y no acumulables
  /// (`image-review-domain`, regla 5): cada fecha se consulta de forma
  /// independiente.
  Future<Either<Failure, DayMatches>> getMatches(DateTime date);
}
