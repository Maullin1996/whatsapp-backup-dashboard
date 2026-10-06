import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Un número anotado por el Revisor, con la lotería de su comprobante.
class RecordedNumber {
  /// Tal cual lo anotó (conserva ceros a la izquierda).
  final String numero;

  /// Identificador de la lotería del comprobante; null en un registro viejo
  /// sin lotería. Puede ser texto libre fuera de la lista (registro viejo).
  final String? loteria;

  const RecordedNumber({required this.numero, required this.loteria});
}

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
  /// el orden en que se anotaron, cada uno con la lotería de su comprobante.
  final List<RecordedNumber> numeros;

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
