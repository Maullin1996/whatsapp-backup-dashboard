import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

abstract class ImageReviewRepository {
  /// Devuelve `Right(null)` si no hay registro de [rol] para [messageId].
  /// Nunca devuelve el registro del otro rol.
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(
    String messageId,
    ReviewRole rol,
  );

  /// Crea o actualiza (los registros son editables), indexado por
  /// (`record.messageId`, `record.rol`). Guardar un rol nunca toca el
  /// registro del otro.
  Future<Either<Failure, Unit>> save(ImageReviewRecord record);
}
