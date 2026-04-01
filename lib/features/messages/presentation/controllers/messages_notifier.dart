import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/messages_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_repository_provider.dart';

class MessagesNotifier extends AsyncNotifier<List<Message>> {
  static const _pageSize = 50;

  final List<Message> _items = [];

  //BATCHING
  final List<Message> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  StreamSubscription<Message>? _newMessagesSub;

  Object? _cursor;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _activeChatJid;

  int _lastKnownTimestamp = 0;

  @override
  FutureOr<List<Message>> build() async {
    final chat = ref.watch(activeChatProvider);

    if (chat == null) {
      reset();
      return const [];
    }

    if (_activeChatJid != chat.chatJid) {
      reset();
      _activeChatJid = chat.chatJid;
      await _loadInitial(chat.chatJid);
    }

    return _items;
  }

  // =========================
  // PAGINACIÓN
  // =========================

  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    if (!_hasMore) return;
    if (_cursor == null) return;
    if (_activeChatJid == null) return;

    _isLoadingMore = true;

    final repo = ref.read(messagesRepositoryProvider);

    final result = await repo.fetchNext(
      chatJid: _activeChatJid!,
      cursor: _cursor!,
      limit: _pageSize,
    );

    result.fold(
      (failure) {
        _isLoadingMore = false;
      },
      (page) {
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;

        if (page.items.isNotEmpty) {
          _items.addAll(page.items);
          state = AsyncData(List.unmodifiable(_items));
        }
        _isLoadingMore = false;
      },
    );
  }

  // =========================
  // CARGA INICIAL
  // =========================

  Future<void> _loadInitial(String chatJid) async {
    state = const AsyncLoading();

    final repo = ref.read(messagesRepositoryProvider);

    final result = await repo.fetchInitial(chatJid: chatJid, limit: _pageSize);

    result.fold(
      (failure) {
        state = AsyncError(failure, StackTrace.current);
      },
      (MessagesPage page) {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;

        _lastKnownTimestamp = _items.isNotEmpty
            ? _items.first.messageTimestamp
            : 0;

        state = AsyncData(List.unmodifiable(_items));

        _startRealtime(chatJid);
      },
    );
  }

  // =========================
  // REALTIME
  // =========================

  void _startRealtime(String chatJid) {
    _newMessagesSub?.cancel();

    final repo = ref.read(messagesRepositoryProvider);

    _newMessagesSub = repo
        .listenNewMessages(
          chatJid: chatJid,
          afterTimestamp: _lastKnownTimestamp,
        )
        .listen(
          _onRealtimerMessage,
          // ✅ Ignora el error de permisos al cerrar sesión
          onError: (error) {
            if (error.toString().contains('permission-denied')) return;
          },
        );
  }

  void _onRealtimerMessage(Message message) {
    if (message.messageTimestamp <= _lastKnownTimestamp) return;
    _buffer.add(message);
    _scheduleFlush();
  }

  // =========================
  // BATCHING
  // =========================

  void _scheduleFlush() {
    if (_isFlushing) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 200), _flushBuffer);
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;

    _isFlushing = true;

    final batch = List<Message>.from(_buffer);
    _buffer.clear();

    for (final msg in batch) {
      final exists = _items.any((m) => m.id == msg.id);
      if (!exists) {
        _items.insert(0, msg); // reverse:true
        _lastKnownTimestamp = _lastKnownTimestamp < msg.messageTimestamp
            ? msg.messageTimestamp
            : _lastKnownTimestamp;
      }
    }
    state = AsyncData(List.unmodifiable(_items));
    _isFlushing = false;
  }

  void reset() {
    _newMessagesSub?.cancel();
    _newMessagesSub = null;

    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    _isFlushing = false;

    _items.clear();
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    _activeChatJid = null;
    _lastKnownTimestamp = 0;

    state = const AsyncData([]);
  }

  // messages_notifier.dart
  void cancelStream() {
    _newMessagesSub?.cancel();
    _newMessagesSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    _isFlushing = false;
  }
}
