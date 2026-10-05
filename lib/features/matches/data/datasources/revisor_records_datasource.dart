import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Lo que Coincidencias necesita de un registro del Revisor subido.
class RevisorRecord {
  final String chatJid;

  /// Jornada del registro (`shiftKey`), nunca [Shift.outOfShift].
  final Shift shift;
  final String messageId;

  /// Referencia de la imagen en Storage.
  final String storagePath;
  final String fechaJornada;

  /// Todos los números del registro, aplanando `comprobantes[].numeros`, en
  /// el orden en que se anotaron (conservan ceros a la izquierda).
  final List<String> numeros;

  const RevisorRecord({
    required this.chatJid,
    required this.shift,
    required this.messageId,
    required this.storagePath,
    required this.fechaJornada,
    required this.numeros,
  });
}

/// Lee los registros del REVISOR de un día, de todos los grupos y jornadas.
abstract class RevisorRecordsDatasource {
  /// Contrato: no lanza. Un error de lectura o un documento con un formato
  /// inesperado devuelven `Left` (con el id del documento); nunca se omite
  /// un documento en silencio.
  Future<Either<Failure, List<RevisorRecord>>> fetchByFechaJornada(
    String fechaJornada,
  );
}
