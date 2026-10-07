import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';

/// Un grupo conocido por el bot (`group_stats`).
typedef KnownGroup = ({String chatJid, String groupName});

/// Lee TODOS los grupos (no solo los que tuvieron ganadores), para que
/// Coincidencias muestre también los grupos con 0 ganadores.
abstract class AllGroupsDatasource {
  /// Contrato: no lanza. Un error de lectura devuelve `Left`; un documento
  /// sin `groupName` de texto usa su id (el `chatJid`) como nombre.
  Future<Either<Failure, List<KnownGroup>>> fetchAll();
}

/// [AllGroupsDatasource] con Firestore: colección `group_stats` (el bot usa
/// el `chatJid` como id del documento). Nunca lanza.
class FirestoreAllGroupsDatasource implements AllGroupsDatasource {
  /// Lectura real contra [firestore].
  FirestoreAllGroupsDatasource(FirebaseFirestore firestore)
    : this.withReader(() async {
        final snapshot = await firestore.collection('group_stats').get();
        return [for (final d in snapshot.docs) (id: d.id, data: d.data())];
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreAllGroupsDatasource.withReader(this._read);

  final Future<List<({String id, Map<String, dynamic> data})>> Function() _read;

  @override
  Future<Either<Failure, List<KnownGroup>>> fetchAll() async {
    try {
      final docs = await _read();
      return Right([
        for (final doc in docs)
          (
            chatJid: doc.id,
            groupName: switch (doc.data['groupName']) {
              final String name when name.isNotEmpty => name,
              _ => doc.id,
            },
          ),
      ]);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return const Left(
        Failure.unknown(message: 'Error inesperado al leer los grupos.'),
      );
    }
  }
}
