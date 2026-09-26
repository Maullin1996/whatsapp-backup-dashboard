import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_local_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';

/// Repositorio persistente de UN usuario ([uid]): lee y escribe solo lo suyo
/// en el almacenamiento local.
class LocalImageReviewRepository implements ImageReviewRepository {
  final ReviewLocalDatasource _datasource;
  final String _uid;

  LocalImageReviewRepository(this._datasource, {required String uid})
    : _uid = uid;

  @override
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(
    String messageId,
    ReviewRole rol,
  ) async {
    final result = await _datasource.get(
      uid: _uid,
      messageId: messageId,
      rol: rol,
    );
    return result.map((model) => model?.record);
  }

  @override
  Future<Either<Failure, Unit>> save(ImageReviewRecord record) =>
      _datasource.put(uid: _uid, model: ImageReviewRecordModel(record));

  @override
  Future<Either<Failure, List<ImageReviewRecord>>> getPending({
    required String chatJid,
    required String fechaJornada,
    required String shift,
    required ReviewRole rol,
  }) async {
    final result = await _datasource.pending(
      uid: _uid,
      rol: rol,
      chatJid: chatJid,
      fechaJornada: fechaJornada,
      shift: shift,
    );
    return result.map((models) => [for (final m in models) m.record]);
  }

  @override
  Future<Either<Failure, List<PendingJornada>>> getPendingJornadas({
    required String chatJid,
    required ReviewRole rol,
  }) => _datasource.pendingJornadas(uid: _uid, rol: rol, chatJid: chatJid);
}
