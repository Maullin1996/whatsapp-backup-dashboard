import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';

/// Lee los datos de un documento por id; `null` si no existe.
typedef DocumentReader =
    Future<Map<String, dynamic>?> Function(String documentId);

/// [GroupNameDatasource] con Firestore: `group_stats/{chatJid}` (el bot usa
/// el `chatJid` como id). Nunca lanza.
class FirestoreGroupNameDatasource implements GroupNameDatasource {
  /// Lectura real contra [firestore].
  FirestoreGroupNameDatasource(FirebaseFirestore firestore)
    : this.withReader((chatJid) async {
        final doc = await firestore
            .collection('group_stats')
            .doc(chatJid)
            .get();
        return doc.exists ? doc.data() : null;
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreGroupNameDatasource.withReader(this._read);

  final DocumentReader _read;

  @override
  Future<Either<Failure, String?>> fetchGroupName(String chatJid) async {
    final Map<String, dynamic>? data;
    try {
      data = await _read(chatJid);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return Left(
        Failure.unknown(
          message: 'Error inesperado al leer el nombre del grupo $chatJid.',
        ),
      );
    }

    if (data == null) return const Right(null);
    final name = data['groupName'];
    if (name is! String) {
      return Left(
        Failure.unknown(
          message:
              'El grupo $chatJid tiene un formato inesperado: el campo '
              '"groupName" ${name == null ? 'falta' : 'no es texto'}.',
        ),
      );
    }
    return Right(name);
  }
}
