import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class ChatsFirestoreDatasource {
  final FirebaseFirestore _db;

  const ChatsFirestoreDatasource(this._db);

  // Obtener grupos permitidos del usuario actual
  Future<List<String>> fetchAllowedGroups(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return [];
    final data = doc.data();
    return List<String>.from(data?['allowedGroups'] ?? []);
  }

  Future<List<Map<String, dynamic>>> fetchChats({
    int limit = 200,
    List<String> allowedGroups = const [],
  }) async {
    // Si no tiene grupos asignados, no mostrar nada
    if (allowedGroups.isEmpty) return [];

    // Firestore whereIn soporta máximo 30 elementos por query
    // Si hay más de 30 grupos, dividir en chunks
    final List<Map<String, dynamic>> results = [];
    final chunks = <List<String>>[];

    for (var i = 0; i < allowedGroups.length; i += 30) {
      chunks.add(
        allowedGroups.sublist(
          i,
          i + 30 > allowedGroups.length ? allowedGroups.length : i + 30,
        ),
      );
    }

    for (final chunk in chunks) {
      final snapshot = await _db
          .collection('group_stats')
          .where('chatJid', whereIn: chunk)
          .orderBy('lastMessageAt', descending: true)
          .limit(limit)
          .get();
      results.addAll(snapshot.docs.map((doc) => doc.data()));
    }

    return results;
  }

  Stream<Map<String, dynamic>> listenNewMessages({
    List<String> allowedGroups = const [],
  }) {
    // Si no tiene grupos asignados, stream vacío
    if (allowedGroups.isEmpty) return const Stream.empty();

    // Firestore whereIn máximo 30 — tomamos el primer chunk para el stream
    // Si hay más de 30, hacemos merge de streams
    final chunks = <List<String>>[];
    for (var i = 0; i < allowedGroups.length; i += 30) {
      chunks.add(
        allowedGroups.sublist(
          i,
          i + 30 > allowedGroups.length ? allowedGroups.length : i + 30,
        ),
      );
    }

    // Merge de todos los streams de cada chunk
    final streams = chunks.map(
      (chunk) => _db
          .collection('group_stats')
          .where('chatJid', whereIn: chunk)
          .orderBy('lastMessageAt', descending: true)
          .snapshots()
          .expand((snapshot) => snapshot.docChanges)
          .where(
            (c) =>
                c.type == DocumentChangeType.added ||
                c.type == DocumentChangeType.modified,
          )
          .map((c) => c.doc.data()!),
    );

    // Combinar todos los streams en uno solo
    return streams.reduce((a, b) => a.mergeWith([b]));
  }
}
