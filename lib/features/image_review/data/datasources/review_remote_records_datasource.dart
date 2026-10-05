import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Lee del servidor los registros ya subidos de una jornada, para que `/review`
/// los reconozca aunque el almacenamiento local se haya perdido (lo subido es
/// la fuente de verdad).
///
/// La implementación con Firestore es `FirestoreReviewRemoteRecordsDatasource`.
abstract class ReviewRemoteRecordsDatasource {
  /// Registros de [rol] de la jornada ([chatJid], [fechaJornada], [shift]),
  /// como sincronizados.
  ///
  /// Contrato:
  /// - Solo los del rol pedido: la regla de lectura exige ese filtro.
  /// - Siempre del servidor, nunca de la caché del SDK: sin conexión es un
  ///   `Left`, no datos viejos.
  /// - Un documento ilegible (falta un campo, otro tipo, fecha ilegible) se
  ///   OMITE con un `debugPrint` de su ruta: esa imagen cuenta como sin
  ///   formulario.
  /// - Un documento legible que no corresponde a la consulta (otro rol,
  ///   grupo, fecha, jornada o un id distinto de `{messageId}_{rol}`) es un
  ///   `Left` entero que lo identifica.
  /// - No lanza excepciones: cualquier error vuelve como `Left`.
  Future<Either<Failure, List<ImageReviewRecordModel>>> fetchJornada({
    required String chatJid,
    required String fechaJornada,
    required Shift shift,
    required ReviewRole rol,
  });
}
