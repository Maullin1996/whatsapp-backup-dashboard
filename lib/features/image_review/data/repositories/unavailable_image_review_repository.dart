import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';

/// Repositorio "no disponible": el almacenamiento local no se pudo abrir.
/// Todo devuelve el mismo `Left`, que el panel ya muestra como error (lectura)
/// o como error de guardado. La app no se cae.
class UnavailableImageReviewRepository implements ImageReviewRepository {
  final Failure failure;

  const UnavailableImageReviewRepository(this.failure);

  @override
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(
    String messageId,
    ReviewRole rol,
  ) async => Left(failure);

  @override
  Future<Either<Failure, Unit>> save(ImageReviewRecord record) async =>
      Left(failure);

  @override
  Future<Either<Failure, List<ImageReviewRecord>>> getPending({
    required String chatJid,
    required String fechaJornada,
    required String shift,
    required ReviewRole rol,
  }) async => Left(failure);
}
