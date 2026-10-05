import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/message_context_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_group_name_datasource.dart';

/// [MessageContextDatasource] con Firestore: `whatsapp_messages/{messageId}`.
/// Nunca lanza.
class FirestoreMessageContextDatasource implements MessageContextDatasource {
  /// Lectura real contra [firestore].
  FirestoreMessageContextDatasource(FirebaseFirestore firestore)
    : this.withReader((messageId) async {
        final doc = await firestore
            .collection('whatsapp_messages')
            .doc(messageId)
            .get();
        return doc.exists ? doc.data() : null;
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreMessageContextDatasource.withReader(this._read);

  final DocumentReader _read;

  @override
  Future<Either<Failure, MessageContext>> fetchById(String messageId) async {
    final Map<String, dynamic>? data;
    try {
      data = await _read(messageId);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return Left(
        Failure.unknown(
          message: 'Error inesperado al leer el mensaje $messageId.',
        ),
      );
    }

    if (data == null) {
      return Left(Failure.unknown(message: 'El mensaje $messageId no existe.'));
    }
    final senderName = data['senderName'];
    final localTime = data['localTime'];
    for (final (field, value) in [
      ('senderName', senderName),
      ('localTime', localTime),
    ]) {
      if (value is! String) {
        return Left(
          Failure.unknown(
            message:
                'El mensaje $messageId tiene un formato inesperado: el campo '
                '"$field" ${value == null ? 'falta' : 'no es texto'}.',
          ),
        );
      }
    }
    return Right((
      senderName: senderName as String,
      localTime: localTime as String,
    ));
  }
}
