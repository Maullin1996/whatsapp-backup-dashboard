import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Registros de revisión del usuario actual (cada implementación ya está
/// ligada a un usuario: la interfaz no recibe uid).
abstract class ImageReviewRepository {
  /// Devuelve `Right(null)` si no hay registro de [rol] para [messageId].
  /// Nunca devuelve el registro del otro rol. Si el registro guardado no se
  /// puede leer, el `Left` identifica el [messageId].
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(
    String messageId,
    ReviewRole rol,
  );

  /// Crea o actualiza (los registros son editables), indexado por
  /// (`record.messageId`, `record.rol`). Guardar un rol nunca toca el
  /// registro del otro.
  Future<Either<Failure, Unit>> save(ImageReviewRecord record);

  /// Registros pendientes de subir de esa jornada: mismo chat, día
  /// ([fechaJornada], `yyyy-MM-dd`), jornada ([shift]) y [rol]. No incluye
  /// los sincronizados. Si algún registro no se puede leer, el `Left`
  /// identifica su messageId.
  Future<Either<Failure, List<ImageReviewRecord>>> getPending({
    required String chatJid,
    required String fechaJornada,
    required String shift,
    required ReviewRole rol,
  });

  /// Jornadas de [chatJid] (de cualquier día) con registros pendientes de
  /// [rol], con la cantidad de cada una. No depende de qué mensajes estén
  /// cargados. Orden estable: por fecha y luego por jornada.
  Future<Either<Failure, List<PendingJornada>>> getPendingJornadas({
    required String chatJid,
    required ReviewRole rol,
  });
}
