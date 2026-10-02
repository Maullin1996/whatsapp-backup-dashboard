import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_raw_document.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/shift_image_counts_datasource.dart';

/// Lee los documentos de un día (los que tengan `shiftDate` igual al valor
/// recibido).
typedef CountsReader = Future<List<RawDocument>> Function(String shiftDate);

/// [ShiftImageCountsDatasource] con Firestore: `shift_image_counts` filtrada
/// por `shiftDate`. Nunca lanza.
class FirestoreShiftImageCountsDatasource
    implements ShiftImageCountsDatasource {
  /// Lectura real contra [firestore].
  FirestoreShiftImageCountsDatasource(FirebaseFirestore firestore)
    : this.withReader((shiftDate) async {
        final snapshot = await firestore
            .collection('shift_image_counts')
            .where('shiftDate', isEqualTo: shiftDate)
            .get();
        return [for (final d in snapshot.docs) (id: d.id, data: d.data())];
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreShiftImageCountsDatasource.withReader(this._read);

  final CountsReader _read;

  @override
  Future<Either<Failure, List<ShiftImageCount>>> fetchByShiftDate(
    String shiftDate,
  ) async {
    final List<RawDocument> docs;
    try {
      docs = await _read(shiftDate);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return Left(
        Failure.unknown(
          message:
              'Error inesperado al leer los contadores de imágenes del día '
              '$shiftDate.',
        ),
      );
    }

    try {
      return Right([for (final doc in docs) parseShiftImageCount(doc)]);
    } on UnexpectedDocumentFormat catch (e) {
      return Left(Failure.unknown(message: e.message));
    }
  }
}

/// Convierte un documento de `shift_image_counts` en [ShiftImageCount];
/// lanza [UnexpectedDocumentFormat] (con el id) si algo falta o no calza.
ShiftImageCount parseShiftImageCount(RawDocument doc) {
  const what = 'El contador';
  return ShiftImageCount(
    chatJid: requireField<String>(doc, 'chatJid', what),
    shift: requireShiftKey(
      doc,
      requireField<String>(doc, 'shiftKey', what),
      what,
    ),
    lastIndex: requireField<int>(doc, 'lastIndex', what),
  );
}
