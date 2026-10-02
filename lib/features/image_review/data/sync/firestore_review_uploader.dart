import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_upload_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';

/// Subida real: arma el documento con
/// [ImageReviewRecordModel.toUploadDocument] y lo escribe con el
/// [ReviewUploadDatasource]. Es el uploader de `reviewUploaderProvider`.
class FirestoreReviewUploader implements ReviewUploader {
  final ReviewUploadDatasource _datasource;

  const FirestoreReviewUploader(this._datasource);

  /// - Registro sin ruta válida: su `Left`, sin llamar al datasource.
  /// - Si no: el resultado del datasource tal cual.
  /// - Si el datasource lanza (rompiendo su contrato): `Left(Failure.unknown)`;
  ///   nunca relanza.
  ///
  /// Todo `Left` deja un `debugPrint` con el messageId y el tipo de error
  /// (sin payload ni chatJid).
  @override
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record) async {
    final result = await _upload(record);
    result.leftMap(
      (failure) => debugPrint(
        '[SUBIDA] falló ${record.messageId}: ${_failureType(failure)}',
      ),
    );
    return result;
  }

  Future<Either<Failure, Unit>> _upload(ImageReviewRecord record) {
    return ImageReviewRecordModel(
      record,
    ).toUploadDocument().fold<Future<Either<Failure, Unit>>>(
      (failure) async => Left(failure),
      (document) async {
        try {
          return await _datasource.setDocument(
            document.pathSegments,
            document.data,
          );
        } catch (_) {
          return Left(
            Failure.unknown(
              message:
                  'Error inesperado al subir el registro '
                  '${record.messageId}.',
            ),
          );
        }
      },
    );
  }

  static String _failureType(Failure failure) => failure.map(
    firestore: (_) => 'firestore',
    unauthorized: (_) => 'unauthorized',
    storage: (_) => 'storage',
    unknown: (_) => 'unknown',
  );
}
