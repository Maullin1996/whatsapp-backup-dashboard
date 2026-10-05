import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/revisor_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_raw_document.dart';

/// Lee los documentos del Revisor de un día (los que tengan `fechaJornada`
/// igual al valor recibido y `rol` revisor).
typedef RevisorRecordsReader =
    Future<List<RawDocument>> Function(String fechaJornada);

/// [RevisorRecordsDatasource] con Firestore: consulta de grupo de
/// colecciones sobre `registros` filtrada por `fechaJornada` y `rol`. Nunca
/// lanza.
class FirestoreRevisorRecordsDatasource implements RevisorRecordsDatasource {
  /// Lectura real contra [firestore].
  FirestoreRevisorRecordsDatasource(FirebaseFirestore firestore)
    : this.withReader((fechaJornada) async {
        final snapshot = await firestore
            .collectionGroup('registros')
            .where('fechaJornada', isEqualTo: fechaJornada)
            .where('rol', isEqualTo: ReviewRole.revisor.name)
            .get();
        return [for (final d in snapshot.docs) (id: d.id, data: d.data())];
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreRevisorRecordsDatasource.withReader(this._read);

  final RevisorRecordsReader _read;

  @override
  Future<Either<Failure, List<RevisorRecord>>> fetchByFechaJornada(
    String fechaJornada,
  ) async {
    final List<RawDocument> docs;
    try {
      docs = await _read(fechaJornada);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return Left(
        Failure.unknown(
          message:
              'Error inesperado al leer los registros del Revisor del día '
              '$fechaJornada.',
        ),
      );
    }

    try {
      return Right([for (final doc in docs) parseRevisorRecord(doc)]);
    } on UnexpectedDocumentFormat catch (e) {
      return Left(Failure.unknown(message: e.message));
    }
  }
}

/// Convierte un documento de `registros` en [RevisorRecord]; lanza
/// [UnexpectedDocumentFormat] (con el id) si algo falta o no calza.
RevisorRecord parseRevisorRecord(RawDocument doc) {
  const what = 'El registro';
  final rol = requireField<String>(doc, 'rol', what);
  if (rol != ReviewRole.revisor.name) {
    throw UnexpectedDocumentFormat(
      '$what ${doc.id} no es del Revisor ("$rol").',
    );
  }

  final comprobantes = requireField<List<dynamic>>(doc, 'comprobantes', what);
  final numeros = <String>[];
  for (final c in comprobantes) {
    final lista = c is Map ? c['numeros'] : null;
    if (lista is! List || lista.any((n) => n is! String)) {
      throw UnexpectedDocumentFormat(
        '$what ${doc.id} tiene un comprobante sin una lista de "numeros" de '
        'texto.',
      );
    }
    numeros.addAll(lista.cast<String>());
  }

  return RevisorRecord(
    chatJid: requireField<String>(doc, 'chatJid', what),
    shift: requireShiftKey(
      doc,
      requireField<String>(doc, 'shiftKey', what),
      what,
    ),
    messageId: requireField<String>(doc, 'messageId', what),
    storagePath: requireField<String>(doc, 'storagePath', what),
    fechaJornada: requireField<String>(doc, 'fechaJornada', what),
    numeros: numeros,
  );
}
