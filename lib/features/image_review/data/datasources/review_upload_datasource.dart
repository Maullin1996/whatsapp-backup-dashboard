import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';

/// Escribe un registro de revisión en el servidor. Es lo único que toca la
/// base de datos en la subida: `FirestoreReviewUploader` arma el documento y
/// delega aquí.
///
/// La implementación con Firestore todavía no existe (la subida sigue
/// SIMULADA); en los tests se usa un datasource falso en memoria.
abstract class ReviewUploadDatasource {
  /// Escribe [data] en el documento de [pathSegments] (colección / documento
  /// alternados, como `ReviewUploadDocument.pathSegments`).
  ///
  /// Contrato:
  /// - REEMPLAZA el documento completo (sin merge): un campo que ya no viene
  ///   en [data] desaparece del documento.
  /// - Idempotente: escribir dos veces lo mismo en el mismo id deja el mismo
  ///   resultado que escribirlo una vez (no crea documentos nuevos).
  /// - No lanza excepciones: cualquier error vuelve como `Left`.
  Future<Either<Failure, Unit>> setDocument(
    List<String> pathSegments,
    Map<String, dynamic> data,
  );
}
