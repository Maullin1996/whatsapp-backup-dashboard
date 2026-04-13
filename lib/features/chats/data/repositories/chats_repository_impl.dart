import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/data/datasources/chats_firestore_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/repositories/chats_repository.dart';

class ChatsRepositoryImpl implements ChatsRepository {
  final ChatsFirestoreDatasource datasource;

  const ChatsRepositoryImpl(this.datasource);

  @override
  Future<List<String>> getAllowedGroups(String uid) async {
    return datasource.fetchAllowedGroups(uid);
  }

  @override
  Future<Either<Failure, List<Chat>>> getChats() async {
    try {
      // Obtener uid del usuario actual
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return const Left(Failure.unknown());

      // Obtener grupos permitidos
      final allowedGroups = await datasource.fetchAllowedGroups(uid);

      final rows = await datasource.fetchChats(
        limit: 200,
        allowedGroups: allowedGroups,
      );

      final Map<String, Chat> chatsByJid = {};

      for (final data in rows) {
        final chatJid = data['chatJid'] as String?;
        final groupName = data['groupName'] as String?;
        final ts = data['lastMessageAt'];
        final tI = data['totalImages'];

        if (chatJid == null || groupName == null || ts == null || tI == null) {
          continue;
        }

        final timestamp = ts is int ? ts : int.tryParse(ts.toString());
        final totalImages = tI is int ? tI : int.tryParse(tI.toString());

        if (timestamp == null || totalImages == null) continue;

        final existing = chatsByJid[chatJid];

        if (existing == null) {
          chatsByJid[chatJid] = Chat(
            chatJid: chatJid,
            groupName: groupName,
            lastMessageAt: ts,
            totalImages: tI,
          );
        } else {
          chatsByJid[chatJid] = Chat(
            chatJid: existing.chatJid,
            groupName: existing.groupName,
            lastMessageAt: existing.lastMessageAt,
            totalImages: tI,
          );
        }
      }

      final chats = chatsByJid.values.toList()
        ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      return Right(chats);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return const Left(Failure.unknown());
    }
  }

  @override
  Stream<Chat> listenChatUpdate() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    // Obtener grupos y luego iniciar stream
    return Stream.fromFuture(datasource.fetchAllowedGroups(uid)).asyncExpand((
      allowedGroups,
    ) {
      return datasource.listenNewMessages(allowedGroups: allowedGroups).map((
        data,
      ) {
        final chatJid = data['chatJid']?.toString() ?? '';
        final groupName = data['groupName']?.toString() ?? '';
        final ts = data['lastMessageAt'];
        final tI = data['totalImages'];

        final timestamp = ts is int
            ? ts
            : int.tryParse(ts?.toString() ?? '') ?? 0;
        final totalImages = tI is int
            ? tI
            : int.tryParse(tI?.toString() ?? '') ?? 0;

        return Chat(
          chatJid: chatJid,
          groupName: groupName,
          lastMessageAt: timestamp,
          totalImages: totalImages,
        );
      });
    });
  }
}
