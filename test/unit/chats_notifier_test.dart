import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/repositories/chats_repository.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/chats_provider.dart';

class FakeChatsRepository implements ChatsRepository {
  FakeChatsRepository(this._initialChats);

  final StreamController<Chat> _controller = StreamController<Chat>();
  List<Chat> _initialChats;
  int getChatsCalls = 0;

  set chats(List<Chat> value) => _initialChats = value;

  @override
  Future<Either<Failure, List<Chat>>> getChats() async {
    getChatsCalls += 1;
    return Right(_initialChats);
  }

  @override
  Stream<Chat> listenChatUpdate() => _controller.stream;

  void emit(Chat chat) => _controller.add(chat);

  Future<void> dispose() => _controller.close();
}

void main() {
  test('build loads and sorts chats by lastMessageAt desc', () async {
    final repo = FakeChatsRepository([
      Chat(
        chatJid: '1',
        groupName: 'Alpha',
        lastMessageAt: 1000,
        totalImages: 1,
      ),
      Chat(
        chatJid: '2',
        groupName: 'Beta',
        lastMessageAt: 2000,
        totalImages: 2,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        chatsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    final chats = await container.read(chatsProvider.future);

    expect(repo.getChatsCalls, 1);
    expect(chats.length, 2);
    expect(chats.first.chatJid, '2');
    expect(chats.last.chatJid, '1');
  });

  test('realtime updates are batched and applied', () async {
    final repo = FakeChatsRepository([
      Chat(
        chatJid: '1',
        groupName: 'Alpha',
        lastMessageAt: 1000,
        totalImages: 1,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        chatsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    await container.read(chatsProvider.future);

    repo.emit(
      Chat(
        chatJid: '1',
        groupName: 'Alpha',
        lastMessageAt: 3000,
        totalImages: 5,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));

    final state = container.read(chatsProvider);
    final chats = state.value!;

    expect(chats.first.lastMessageAt, 3000);
    expect(chats.first.totalImages, 5);
  });

  test('cancelStream stops realtime updates', () async {
    final repo = FakeChatsRepository([
      Chat(
        chatJid: '1',
        groupName: 'Alpha',
        lastMessageAt: 1000,
        totalImages: 1,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        chatsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    await container.read(chatsProvider.future);

    container.read(chatsProvider.notifier).cancelStream();

    repo.emit(
      Chat(
        chatJid: '1',
        groupName: 'Alpha',
        lastMessageAt: 3000,
        totalImages: 5,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));

    final state = container.read(chatsProvider);
    final chats = state.value!;

    expect(chats.first.lastMessageAt, 1000);
    expect(chats.first.totalImages, 1);
  });

  test('refresh reloads chats from repository', () async {
    final repo = FakeChatsRepository([
      Chat(
        chatJid: '1',
        groupName: 'Alpha',
        lastMessageAt: 1000,
        totalImages: 1,
      ),
    ]);

    final container = ProviderContainer(
      overrides: [
        chatsRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(repo.dispose);

    await container.read(chatsProvider.future);

    repo.chats = [
      Chat(
        chatJid: '2',
        groupName: 'Beta',
        lastMessageAt: 2000,
        totalImages: 2,
      ),
    ];

    await container.read(chatsProvider.notifier).refresh();

    final state = container.read(chatsProvider);
    final chats = state.value!;

    expect(repo.getChatsCalls, 2);
    expect(chats.length, 1);
    expect(chats.first.chatJid, '2');
  });
}
