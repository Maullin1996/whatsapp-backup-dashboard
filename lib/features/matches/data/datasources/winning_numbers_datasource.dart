import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';

/// Lee los ganadores de un día, cada uno con su lotería.
abstract class WinningNumbersDatasource {
  /// Lista vacía si el día no tiene documento o el documento no trae
  /// `entries` ("todavía no hay ganadores"; no es un error).
  ///
  /// Contrato: no lanza. Un error de lectura o un `entries` con un formato
  /// inesperado devuelven `Left`.
  Future<Either<Failure, List<WinningEntry>>> fetchByFecha(String fecha);
}
