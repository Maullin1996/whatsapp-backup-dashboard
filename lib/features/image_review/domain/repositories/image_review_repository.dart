import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';

abstract class ImageReviewRepository {
  /// Devuelve `Right(null)` si no hay registro para [messageId].
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(String messageId);

  /// Crea o actualiza (los registros son editables), indexado por
  /// `record.messageId`.
  Future<Either<Failure, Unit>> save(ImageReviewRecord record);
}
