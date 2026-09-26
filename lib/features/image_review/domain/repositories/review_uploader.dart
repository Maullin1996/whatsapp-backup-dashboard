import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';

/// Sube un registro de revisión al servidor. Subir el mismo registro dos
/// veces debe ser seguro (idempotente): si la subida se corta a mitad, el
/// registro sigue pendiente y se vuelve a subir.
abstract class ReviewUploader {
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record);
}
