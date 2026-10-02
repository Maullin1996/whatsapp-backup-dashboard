import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';

/// Lee los números ganadores de un día.
abstract class WinningNumbersDatasource {
  /// Lista vacía si el día no tiene documento (no es un error).
  ///
  /// Contrato: no lanza. Un error de lectura o un documento con un formato
  /// inesperado devuelven `Left`.
  Future<Either<Failure, List<String>>> fetchByFecha(String fecha);
}
