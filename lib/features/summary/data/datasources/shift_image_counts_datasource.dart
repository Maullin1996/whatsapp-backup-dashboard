import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Un contador que publica el bot en `shift_image_counts`.
class ShiftImageCount {
  final String chatJid;

  /// Nunca [Shift.outOfShift] (el bot no la publica).
  final Shift shift;

  /// Último número entregado, NO una cantidad: puede ser mayor que las
  /// imágenes reales (huecos, dobles conteos) y cuenta toda la media.
  final int lastIndex;

  const ShiftImageCount({
    required this.chatJid,
    required this.shift,
    required this.lastIndex,
  });
}

/// Lee los contadores del bot de un día, de todos los grupos.
abstract class ShiftImageCountsDatasource {
  /// Contadores con `shiftDate == [shiftDate]` (`yyyy-MM-dd`). Una jornada
  /// sin media no tiene documento: no aparece en la lista.
  ///
  /// Contrato: no lanza. Un error de lectura o un documento con formato
  /// inesperado devuelven `Left`.
  Future<Either<Failure, List<ShiftImageCount>>> fetchByShiftDate(
    String shiftDate,
  );
}
