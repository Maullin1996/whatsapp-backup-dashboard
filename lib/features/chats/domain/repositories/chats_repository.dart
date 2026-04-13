import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
//lib/feature/chats/domain/repositories/chats_repository.dart

abstract class ChatsRepository {
  Future<Either<Failure, List<Chat>>> getChats();
  Stream<Chat> listenChatUpdate();
  Future<List<String>> getAllowedGroups(String uid); // ← nuevo
}
