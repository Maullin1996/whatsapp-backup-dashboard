import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';

abstract class SummaryRepository {
  /// Resumen por grupo y jornada del día [fecha] (solo cuenta el día, no la
  /// hora). Lista vacía si no hay nada registrado ese día.
  Future<Either<Failure, List<JornadaSummary>>> getJornadaSummaries(
    DateTime fecha,
  );
}
