import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Lo que el Resumen necesita de un registro subido a `image_reviews`: de qué
/// grupo, jornada y rol es, y el total de cada comprobante. Los números no
/// importan para el Resumen.
class SummaryRecord {
  final String chatJid;
  final String fechaJornada;

  /// Nunca [Shift.outOfShift] (un registro así no se acepta al leer).
  final Shift shift;
  final ReviewRole rol;

  /// El total de cada comprobante, en el orden en que vienen.
  final List<int> totales;

  const SummaryRecord({
    required this.chatJid,
    required this.fechaJornada,
    required this.shift,
    required this.rol,
    required this.totales,
  });
}

/// Lee los registros de revisión de un día, de TODOS los grupos (nombres
/// PROVISIONALES, igual que la ruta de subida).
abstract class SummaryRecordsDatasource {
  /// Registros con `fechaJornada == [fechaJornada]` (`yyyy-MM-dd`).
  ///
  /// Contrato: no lanza. Un error de lectura o un documento con formato
  /// inesperado devuelven `Left` (un registro nunca se omite en silencio:
  /// falsearía la reconciliación).
  Future<Either<Failure, List<SummaryRecord>>> fetchByFechaJornada(
    String fechaJornada,
  );
}
