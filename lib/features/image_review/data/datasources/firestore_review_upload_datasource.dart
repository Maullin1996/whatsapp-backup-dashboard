import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_upload_datasource.dart';

/// Escribe [data] en el documento de [path] (segmentos unidos con "/").
typedef ReviewDocumentWriter =
    Future<void> Function(String path, Map<String, dynamic> data);

/// Tiempo máximo para escribir UN registro. Si se pasa, ese registro falla
/// (sigue pendiente) y la subida de la jornada continúa con el siguiente.
const Duration reviewUploadTimeout = Duration(seconds: 15);

/// [ReviewUploadDatasource] con Firestore: `doc(path).set(data)` SIN
/// `SetOptions`, así que reemplaza el documento completo (sin merge) y, con el
/// mismo id, es idempotente. Nunca lanza: todo error vuelve como `Left`.
///
/// TODAVÍA NO CONECTADO: nada la construye fuera de los tests y
/// `reviewUploaderProvider` sigue usando el uploader simulado.
class FirestoreReviewUploadDatasource implements ReviewUploadDatasource {
  /// Escritura real contra [firestore].
  FirestoreReviewUploadDatasource(
    FirebaseFirestore firestore, {
    Duration timeout = reviewUploadTimeout,
  }) : this.withWriter(
         (path, data) => firestore.doc(path).set(data),
         timeout: timeout,
       );

  /// Con una función de escritura propia (para probar sin Firebase).
  const FirestoreReviewUploadDatasource.withWriter(
    this._write, {
    this.timeout = reviewUploadTimeout,
  });

  final ReviewDocumentWriter _write;
  final Duration timeout;

  @override
  Future<Either<Failure, Unit>> setDocument(
    List<String> pathSegments,
    Map<String, dynamic> data,
  ) async {
    // La ruta ya la valida `toUploadDocument`; esto solo evita escribir en
    // otro lugar si llegara una inválida (un documento tiene un número par de
    // segmentos, ninguno vacío ni con "/").
    if (pathSegments.isEmpty ||
        pathSegments.length.isOdd ||
        pathSegments.any((s) => s.isEmpty || s.contains('/'))) {
      return Left(
        Failure.unknown(
          message: 'Ruta de subida inválida: ${pathSegments.join(' | ')}',
        ),
      );
    }

    final path = pathSegments.join('/');
    try {
      await _write(path, data).timeout(timeout);
      return const Right(unit);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } on TimeoutException {
      return Left(
        Failure.unknown(
          message: 'El registro no se pudo subir a tiempo ($path).',
        ),
      );
    } catch (_) {
      return Left(
        Failure.unknown(
          message: 'Error inesperado al subir el registro ($path).',
        ),
      );
    }
  }
}
