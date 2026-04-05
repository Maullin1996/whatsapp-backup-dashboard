import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/messages_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/repositories/messages_repository.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_repository_provider.dart';

class FakeMessagesRepository implements MessagesRepository {
  FakeMessagesRepository({
    required MessagesPage initialPage,
    MessagesPage? nextPage,
  })  : _initialPage = initialPage,
        _nextPage = nextPage;

  final StreamController<Message> _controller = StreamController<Message>();
  MessagesPage _initialPage;
  MessagesPage? _nextPage;

  int fetchInitialCalls = 0;
  int fetchNextCalls = 0;
  String? lastChatJidInitial;
  int? lastLimitInitial;
  String? lastChatJidListen;
  int? lastAfterTimestamp;
  String? lastChatJidNext;
  Object? lastCursorNext;

  set initialPage(MessagesPage value) => _initialPage = value;
  set nextPage(MessagesPage? value) => _nextPage = value;

  @override
  Future<Either<Failure, MessagesPage>> fetchInitial({
    required String chatJid,
    int limit = 50,
  }) async {
    fetchInitialCalls += 1;
    lastChatJidInitial = chatJid;
    lastLimitInitial = limit;
    return Right(_initialPage);
  }

  @override
  Future<Either<Failure, MessagesPage>> fetchNext({
    required String chatJid,
    required Object cursor,
    int limit = 50,
  }) async {
    fetchNextCalls += 1;
    lastChatJidNext = chatJid;
    lastCursorNext = cursor;
    return Right(_nextPage ?? MessagesPage(items: const [], nextCursor: null));
  }

  @override
  Stream<Message> listenNewMessages({
    required String chatJid,
    required int afterTimestamp,
  }) {
    lastChatJidListen = chatJid;
    lastAfterTimestamp = afterTimestamp;
    return _controller.stream;
  }

  void emit(Message message) => _controller.add(message);

  Future<void> dispose() => _controller.close();
}

Message _message({
  required String id,
  required String chatJid,
  required int ts,
}) {
  return Message(
    id: id,
    chatJid: chatJid,
    senderName: 'Tester',
    caption: null,
    storagePath: null,
    hasMedia: false,
    messageTimestamp: ts,
    localTime: '10:00',
    shift: 'AM',
    messageDate: '2026-04-05',
  );
}

void main() {
  test('build loads initial messages and starts realtime', () async {
    final chat = Chat(
      chatJid: 'jid-1',
      groupName: 'Grupo 1',
      lastMessageAt: 0,
      totalImages: 0,
    );

    final repo = FakeMessagesRepository(
      initialPage: MessagesPage(
        items: [
          _message(id: 'm2', chatJid: chat.chatJid, ts: 2000),
          _message(id: 'm1', chatJid: chat.chatJid, ts: 1000),
        ],
        nextCursor: 'cursor-1',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    container.read(activeChatProvider.notifier).select(chat);

    final messages = await container.read(messagesProvider.future);

    expect(repo.fetchInitialCalls, 1);
    expect(repo.lastChatJidInitial, chat.chatJid);
    expect(repo.lastChatJidListen, chat.chatJid);
    expect(repo.lastAfterTimestamp, 2000);
    expect(messages.length, 2);
    expect(messages.first.id, 'm2');
  });

  test('realtime updates are batched and de-duplicated', () async {
    final chat = Chat(
      chatJid: 'jid-1',
      groupName: 'Grupo 1',
      lastMessageAt: 0,
      totalImages: 0,
    );

    final repo = FakeMessagesRepository(
      initialPage: MessagesPage(
        items: [
          _message(id: 'm1', chatJid: chat.chatJid, ts: 1000),
        ],
        nextCursor: 'cursor-1',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    container.read(activeChatProvider.notifier).select(chat);
    await container.read(messagesProvider.future);

    repo.emit(_message(id: 'm2', chatJid: chat.chatJid, ts: 3000));
    repo.emit(_message(id: 'm1', chatJid: chat.chatJid, ts: 2000));

    await Future<void>.delayed(const Duration(milliseconds: 250));

    final state = container.read(messagesProvider);
    final messages = state.value!;

    expect(messages.length, 2);
    expect(messages.first.id, 'm2');
  });

  test('loadMore appends older messages', () async {
    final chat = Chat(
      chatJid: 'jid-1',
      groupName: 'Grupo 1',
      lastMessageAt: 0,
      totalImages: 0,
    );

    final repo = FakeMessagesRepository(
      initialPage: MessagesPage(
        items: [
          _message(id: 'm2', chatJid: chat.chatJid, ts: 2000),
        ],
        nextCursor: 'cursor-1',
      ),
      nextPage: MessagesPage(
        items: [
          _message(id: 'm1', chatJid: chat.chatJid, ts: 1000),
        ],
        nextCursor: null,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    container.read(activeChatProvider.notifier).select(chat);
    await container.read(messagesProvider.future);

    await container.read(messagesProvider.notifier).loadMore();

    final state = container.read(messagesProvider);
    final messages = state.value!;

    expect(repo.fetchNextCalls, 1);
    expect(messages.length, 2);
    expect(messages.last.id, 'm1');
  });

  test('cancelStream stops realtime updates', () async {
    final chat = Chat(
      chatJid: 'jid-1',
      groupName: 'Grupo 1',
      lastMessageAt: 0,
      totalImages: 0,
    );

    final repo = FakeMessagesRepository(
      initialPage: MessagesPage(
        items: [
          _message(id: 'm1', chatJid: chat.chatJid, ts: 1000),
        ],
        nextCursor: 'cursor-1',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        messagesRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    container.read(activeChatProvider.notifier).select(chat);
    await container.read(messagesProvider.future);

    container.read(messagesProvider.notifier).cancelStream();

    repo.emit(_message(id: 'm2', chatJid: chat.chatJid, ts: 2000));
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final state = container.read(messagesProvider);
    final messages = state.value!;

    expect(messages.length, 1);
    expect(messages.first.id, 'm1');
  });
}
