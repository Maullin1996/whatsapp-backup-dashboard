import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/datasources/edit_attempts_firestore_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/messages_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/repositories/messages_repository.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/date_filter_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/firestore_providers.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_repository_provider.dart';

Message _msg(String id, int ts, {bool image = true, int? index}) => Message(
  id: id,
  chatJid: 'c1',
  senderName: 'Ana',
  hasMedia: image,
  storagePath: image ? 'img/$id.jpg' : null,
  messageTimestamp: ts,
  localTime: '',
  shift: '',
  messageDate: '',
  shiftImageIndex: index,
);

/// Devuelve los mensajes tal cual (desordenados) en una sola página.
class _FakeRepo implements MessagesRepository {
  final List<Message> messages;
  _FakeRepo(this.messages);

  @override
  Future<Either<Failure, MessagesPage>> fetchByDateRange({
    required String chatJid,
    required int fromTimestamp,
    required int toTimestamp,
    int limit = 50,
    Object? cursor,
  }) async => Right(MessagesPage(items: messages, nextCursor: null));

  @override
  Stream<Message> listenNewMessages({
    required String chatJid,
    required int afterTimestamp,
  }) => const Stream.empty();

  @override
  Future<Either<Failure, MessagesPage>> fetchInitial({
    required String chatJid,
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, MessagesPage>> fetchNext({
    required String chatJid,
    required Object cursor,
    int limit = 50,
  }) => throw UnimplementedError();
}

class _NoEdits implements EditAttemptsFirestoreDatasource {
  @override
  Future<Set<String>> fetchEditedMessageIds(List<String> messageIds) async =>
      {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('orden del visor del chat: la imagen más nueva en el índice 0, sin '
      'mensajes de texto (con el orden real de MessagesNotifier)', () async {
    final container = ProviderContainer(
      overrides: [
        messagesRepositoryProvider.overrideWithValue(
          _FakeRepo([
            _msg('vieja', 1000),
            _msg('nueva', 3000),
            _msg('texto', 4000, image: false),
            _msg('empate-1', 2000, index: 1),
            _msg('empate-2', 2000, index: 2),
          ]),
        ),
        editAttemptsDatasourceProvider.overrideWithValue(_NoEdits()),
      ],
    );
    addTearDown(container.dispose);

    // Un día pasado: sin escucha en tiempo real.
    container
        .read(dateFilterProvider.notifier)
        .setFilter(DateFilterSpecificDay(date: DateTime(2026, 9, 28)));
    container
        .read(activeChatProvider.notifier)
        .select(
          Chat(chatJid: 'c1', groupName: 'G', lastMessageAt: 0, totalImages: 0),
        );
    await container.read(messagesProvider.future);

    expect(container.read(chatImageItemsProvider).map((i) => i.messageId), [
      'nueva',
      'empate-2',
      'empate-1',
      'vieja',
    ]);
  });
}
