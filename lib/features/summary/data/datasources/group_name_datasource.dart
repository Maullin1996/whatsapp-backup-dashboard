import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';

/// Lee el nombre de un grupo (`group_stats/{chatJid}.groupName`).
abstract class GroupNameDatasource {
  /// `Right(null)` si el documento no existe.
  ///
  /// Contrato: no lanza. Un error de lectura o un `groupName` que no es texto
  /// devuelven `Left`.
  Future<Either<Failure, String?>> fetchGroupName(String chatJid);
}
