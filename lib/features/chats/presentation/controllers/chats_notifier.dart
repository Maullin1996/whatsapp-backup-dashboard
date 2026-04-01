import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';

//lib/feature/chats/presentation/provider/chats_notifier.dart
class ChatsNotifier extends AsyncNotifier<List<Chat>> {
  final Map<String, Chat> _chatsByJid = {};

  //batching
  final List<Chat> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  StreamSubscription<Chat>? _realtimeSub;

  int _lastKnownTimestamp = 0;

  @override
  Future<List<Chat>> build() async {
    ref.onDispose(() {
      _realtimeSub?.cancel();
      _realtimeSub = null;

      _flushTimer?.cancel();
      _flushTimer = null;

      _buffer.clear();
      _isFlushing = false;
    });
    final chats = await _loadChats();
    _startRealtime();
    return chats;
  }

  // =========================
  // CARGA INICIAL
  // =========================
  Future<List<Chat>> _loadChats() async {
    final repository = ref.read(chatsRepositoryProvider);
    final result = await repository.getChats();

    return result.fold((failure) => throw failure, (chats) {
      _chatsByJid.clear();
      _lastKnownTimestamp = 0;

      for (final chat in chats) {
        _chatsByJid[chat.chatJid] = chat;
        if (chat.lastMessageAt > _lastKnownTimestamp) {
          _lastKnownTimestamp = chat.lastMessageAt;
        }
      }
      return _sortedChats();
    });
  }

  // =========================
  // REALTIME
  // =========================
  void _startRealtime() {
    _realtimeSub?.cancel();

    final repository = ref.read(chatsRepositoryProvider);

    _realtimeSub = repository.listenChatUpdate().listen(
      _onRealtimeChat,
      onError: (error) {
        if (error.toString().contains('permission-denied')) return;
      },
    );
  }

  void _onRealtimeChat(Chat update) {
    if (update.lastMessageAt <= _lastKnownTimestamp) return;
    _buffer.add(update);
    _scheduleFlush();
  }

  void _scheduleFlush() {
    if (_isFlushing) return;

    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 250), _flushBuffer);
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;

    _isFlushing = true;

    final batch = List<Chat>.from(_buffer);
    _buffer.clear();

    for (final update in batch) {
      final existing = _chatsByJid[update.chatJid];

      if (existing == null) {
        _chatsByJid[update.chatJid] = update;
      } else {
        _chatsByJid[update.chatJid] = Chat(
          chatJid: existing.chatJid,
          groupName: existing.groupName,
          lastMessageAt: update.lastMessageAt,
          totalImages: update.totalImages,
        );
      }
      if (update.lastMessageAt > _lastKnownTimestamp) {
        _lastKnownTimestamp = update.lastMessageAt;
      }
    }
    state = AsyncData(_sortedChats());
    _isFlushing = false;
  }

  // =========================
  // HELPERS
  // =========================
  List<Chat> _sortedChats() {
    final list = _chatsByJid.values.toList();
    list.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));
    return list;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadChats);
  }

  void reset() {
    _realtimeSub?.cancel();
    _realtimeSub = null;

    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    _isFlushing = false;

    _chatsByJid.clear();

    _lastKnownTimestamp = 0;
  }

  void cancelStream() {
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    _isFlushing = false;
  }
}
