import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/models/raw_edit_attempt_model.dart';

class EditAttemptsFirestoreDatasource {
  final FirebaseFirestore _firestore;

  const EditAttemptsFirestoreDatasource(this._firestore);

  Future<Set<String>> fetchEditedMessageIds(List<String> messageIds) async {
    if (messageIds.isEmpty) return {};

    // Firestore limita whereIn a 30 elementos por query
    final chunks = <List<String>>[];
    for (var i = 0; i < messageIds.length; i += 30) {
      chunks.add(
        messageIds.sublist(
          i,
          i + 30 > messageIds.length ? messageIds.length : i + 30,
        ),
      );
    }

    final editedIds = <String>{};

    for (final chunk in chunks) {
      final snapshot = await _firestore
          .collection('edit_attempts')
          .where('messageId', whereIn: chunk)
          .get();

      for (final doc in snapshot.docs) {
        final model = RawEditAttemptModel.fromFirestore(doc.data());
        editedIds.add(model.messageId);
      }
    }

    return editedIds;
  }
}
