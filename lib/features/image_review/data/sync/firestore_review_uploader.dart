import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_upload_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';

/// Subida real: arma el documento con
/// [ImageReviewRecordModel.toUploadDocument] (la misma ruta y los mismos datos
/// que imprime `SimulatedReviewUploader`) y lo escribe con el
/// [ReviewUploadDatasource].
///
/// TODAVÍA NO CONECTADO: `reviewUploaderProvider` sigue usando el uploader
/// simulado, y no existe la implementación del datasource con Firestore.
class FirestoreReviewUploader implements ReviewUploader {
  final ReviewUploadDatasource _datasource;

  const FirestoreReviewUploader(this._datasource);

  /// - Registro sin ruta válida: su `Left`, sin llamar al datasource.
  /// - Si no: el resultado del datasource tal cual.
  /// - Si el datasource lanza (rompiendo su contrato): `Left(Failure.unknown)`;
  ///   nunca relanza.
  @override
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record) {
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
}
