import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/models/raw_message_model.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/helpers/to_domain.dart';

class FirestoreMessagePage {
  final List<RawMessageModel> items;
  final DocumentSnapshot? lastDoc;

  const FirestoreMessagePage({required this.items, required this.lastDoc});
}

class MessagesFirestoreDatasource {
  final FirebaseFirestore _firestore;

  const MessagesFirestoreDatasource(this._firestore);

  static const _pageSize = 50;

  Future<Either<Failure, FirestoreMessagePage>> fetchInitial({
    required String chatJid,
    int limit = _pageSize,
  }) async {
    try {
      final query = await _firestore
          .collection('whatsapp_messages')
          .where('chatJid', isEqualTo: chatJid)
          .orderBy('messageTimestamp', descending: true)
          .limit(limit)
          .get();

      final items = query.docs
          .map((doc) => RawMessageModel.fromFirestore(doc.id, doc.data()))
          .toList();

      return Right(
        FirestoreMessagePage(
          items: items,
          lastDoc: query.docs.isNotEmpty ? query.docs.last : null,
        ),
      );
    } catch (e) {
      return Left(mapFirestoreError(e));
    }
  }

  Future<Either<Failure, FirestoreMessagePage>> fetchNext({
    required String chatJid,
    required DocumentSnapshot lastDoc,
    int limit = _pageSize,
  }) async {
    try {
      final query = await _firestore
          .collection('whatsapp_messages')
          .where('chatJid', isEqualTo: chatJid)
          .orderBy('messageTimestamp', descending: true)
          .startAfterDocument(lastDoc)
          .limit(limit)
          .get();
      final items = query.docs
          .map((doc) => RawMessageModel.fromFirestore(doc.id, doc.data()))
          .toList();

      return Right(
        FirestoreMessagePage(
          items: items,
          lastDoc: query.docs.isNotEmpty ? query.docs.last : null,
        ),
      );
    } catch (e) {
      return Left(mapFirestoreError(e));
    }
  }

  Future<Either<Failure, FirestoreMessagePage>> fetchByDateRange({
    required String chatJid,
    required int fromTimestamp,
    required int toTimestamp,
    int limit = _pageSize,
  }) async {
    try {
      final query = await _firestore
          .collection('whatsapp_messages')
          .where('chatJid', isEqualTo: chatJid)
          .where('messageTimestamp', isGreaterThanOrEqualTo: fromTimestamp)
          .where('messageTimestamp', isLessThanOrEqualTo: toTimestamp)
          .orderBy('messageTimestamp', descending: true)
          .limit(limit)
          .get();

      final items = query.docs
          .map((doc) => RawMessageModel.fromFirestore(doc.id, doc.data()))
          .toList();

      return Right(
        FirestoreMessagePage(
          items: items,
          lastDoc: query.docs.isNotEmpty ? query.docs.last : null,
        ),
      );
    } catch (e) {
      return Left(mapFirestoreError(e));
    }
  }

  Stream<Message> listemNewMessages({
    required String chatJid,
    required int afterTimestamp,
  }) {
    final query = _firestore
        .collection('whatsapp_messages')
        .where('chatJid', isEqualTo: chatJid)
        .where('messageTimestamp', isGreaterThan: afterTimestamp)
        .orderBy('messageTimestamp', descending: false);

    return query
        .snapshots()
        .expand((snapshot) {
          return snapshot.docChanges
              .where((c) => c.type == DocumentChangeType.added)
              .map((c) => c.doc);
        })
        .map((doc) {
          final raw = RawMessageModel.fromFirestore(doc.id, doc.data()!);
          return toDomain(raw);
        });
  }
}
