import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_raw_document.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/summary_records_datasource.dart';

/// Lee los documentos de un día (los que tengan `fechaJornada` igual al
/// valor recibido).
typedef RecordsReader = Future<List<RawDocument>> Function(String fechaJornada);

/// [SummaryRecordsDatasource] con Firestore: una consulta de grupo de
/// colecciones sobre `registros` (los registros de TODOS los grupos y
/// jornadas, ver la ruta de subida) filtrada por `fechaJornada`. Nunca lanza.
class FirestoreSummaryRecordsDatasource implements SummaryRecordsDatasource {
  /// Lectura real contra [firestore].
  FirestoreSummaryRecordsDatasource(FirebaseFirestore firestore)
    : this.withReader((fechaJornada) async {
        final snapshot = await firestore
            .collectionGroup('registros')
            .where('fechaJornada', isEqualTo: fechaJornada)
            .get();
        return [for (final d in snapshot.docs) (id: d.id, data: d.data())];
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreSummaryRecordsDatasource.withReader(this._read);

  final RecordsReader _read;

  @override
  Future<Either<Failure, List<SummaryRecord>>> fetchByFechaJornada(
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
              'Error inesperado al leer los registros del día $fechaJornada.',
        ),
      );
    }

    try {
      return Right([for (final doc in docs) parseSummaryRecord(doc)]);
    } on UnexpectedDocumentFormat catch (e) {
      return Left(Failure.unknown(message: e.message));
    }
  }
}

/// Convierte un documento de `registros` en [SummaryRecord]; lanza
/// [UnexpectedDocumentFormat] (con el id) si algo falta o no calza.
SummaryRecord parseSummaryRecord(RawDocument doc) {
  const what = 'El registro';
  final rolName = requireField<String>(doc, 'rol', what);
  final rol = ReviewRole.values.asNameMap()[rolName];
  if (rol == null) {
    throw UnexpectedDocumentFormat(
      '$what ${doc.id} tiene un rol inválido ("$rolName").',
    );
  }

  final comprobantes = requireField<List<dynamic>>(doc, 'comprobantes', what);
  final totales = <int>[];
  for (final c in comprobantes) {
    final total = c is Map ? c['total'] : null;
    if (total is! int) {
      throw UnexpectedDocumentFormat(
        '$what ${doc.id} tiene un comprobante sin un "total" entero.',
      );
    }
    totales.add(total);
  }

  return SummaryRecord(
    chatJid: requireField<String>(doc, 'chatJid', what),
    fechaJornada: requireField<String>(doc, 'fechaJornada', what),
    shift: requireShiftKey(
      doc,
      requireField<String>(doc, 'shiftKey', what),
      what,
    ),
    rol: rol,
    totales: totales,
  );
}
