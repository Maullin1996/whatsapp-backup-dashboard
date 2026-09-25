import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';

/// Implementación temporal en memoria (se pierde al cerrar la app).
///
/// Se reemplaza por una persistencia local real (Hive/SQLite) creando otra
/// implementación de [ImageReviewRepository]; domain no cambia.
class InMemoryImageReviewRepository implements ImageReviewRepository {
  final Map<String, ImageReviewRecord> _records = {};

  @override
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(
    String messageId,
  ) async => Right(_records[messageId]);

  @override
  Future<Either<Failure, Unit>> save(ImageReviewRecord record) async {
    _records[record.messageId] = record;
    return const Right(unit);
  }
}
