import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';

/// Repositorio sin sesión: no hay usuario, así que no hay registros que
/// ver (lecturas vacías) ni dónde guardar (`save` -> no autorizado). No toca
/// el almacenamiento: los datos del último usuario siguen guardados.
class NoSessionImageReviewRepository implements ImageReviewRepository {
  const NoSessionImageReviewRepository();

  @override
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(
    String messageId,
    ReviewRole rol,
  ) async => const Right(null);

  @override
  Future<Either<Failure, Unit>> save(ImageReviewRecord record) async =>
      const Left(Failure.unauthorized());

  @override
  Future<Either<Failure, List<ImageReviewRecord>>> getPending({
    required String chatJid,
    required String fechaJornada,
    required String shift,
    required ReviewRole rol,
  }) async => const Right([]);

  @override
  Future<Either<Failure, List<PendingJornada>>> getPendingJornadas({
    required String chatJid,
    required ReviewRole rol,
  }) async => const Right([]);
}
