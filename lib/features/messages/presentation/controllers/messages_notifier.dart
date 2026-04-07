import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/messages_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/date_filter_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_repository_provider.dart';

class MessagesNotifier extends AsyncNotifier<List<Message>> {
  static const _pageSize = 50;

  final List<Message> _items = [];

  // BATCHING
  final List<Message> _buffer = [];
  Timer? _flushTimer;
  bool isFlushing = false;

  StreamSubscription<Message>? _newMessagesSub;

  Object? _cursor;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _activeChatJid;
  DateFilter _activeFilter = const DateFilterTodayAndYesterday();

  int _lastKnownTimestamp = 0;

  @override
  FutureOr<List<Message>> build() async {
    final chat = ref.watch(activeChatProvider);
    final filter = ref.watch(dateFilterProvider);

    if (chat == null) {
      reset();
      return const [];
    }

    final chatChanged = _activeChatJid != chat.chatJid;
    final filterChanged =
        _activeFilter.runtimeType != filter.runtimeType ||
        _filterKey(filter) != _filterKey(_activeFilter);

    if (chatChanged || filterChanged) {
      reset();
      _activeChatJid = chat.chatJid;
      _activeFilter = filter;
      await _loadFiltered(chat.chatJid, filter);
    }
    return _items;
  }

  String _filterKey(DateFilter f) {
    if (f is DateFilterSpecificDay) {
      return 'specific_${f.date.year}_${f.date.month}_${f.date.day}';
    }
    return f.runtimeType.toString();
  }

  Future<void> _loadFiltered(String chatJid, DateFilter filter) async {
    state = const AsyncLoading();

    final repo = ref.read(messagesRepositoryProvider);
    final range = filter.toTimestampRange();

    final result = await repo.fetchByDateRange(
      chatJid: chatJid,
      fromTimestamp: range.from,
      toTimestamp: range.to,
      limit: _pageSize,
    );

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
            : DateTime.now().millisecondsSinceEpoch;

        state = AsyncData(List.unmodifiable(_items));

        if (filter.includestoday) {
          _startRealtime(chatJid);
        }
      },
    );
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
    final range = _activeFilter.toTimestampRange();

    final result = await repo.fetchByDateRange(
      chatJid: _activeChatJid!,
      fromTimestamp: range.from,
      toTimestamp: range.to,
      limit: _pageSize,
      cursor: _cursor,
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

  // // =========================
  // // CARGA INICIAL
  // // =========================

  // Future<void> _loadInitial(String chatJid) async {
  //   state = const AsyncLoading();

  //   final repo = ref.read(messagesRepositoryProvider);

  //   final result = await repo.fetchInitial(chatJid: chatJid, limit: _pageSize);

  //   result.fold(
  //     (failure) {
  //       state = AsyncError(failure, StackTrace.current);
  //     },
  //     (MessagesPage page) {
  //       _items
  //         ..clear()
  //         ..addAll(page.items);
  //       _cursor = page.nextCursor;
  //       _hasMore = page.nextCursor != null;

  //       _lastKnownTimestamp = _items.isNotEmpty
  //           ? _items.first.messageTimestamp
  //           : 0;

  //       state = AsyncData(List.unmodifiable(_items));

  //       _startRealtime(chatJid);
  //     },
  //   );
  // }

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
          onError: (error) {
            if (error.toString().contains('permission-denied')) return;
          },
        );
  }

  void _onRealtimerMessage(Message message) {
    // ✅ FIX 1: < en vez de <= para no descartar mensajes con mismo timestamp
    if (message.messageTimestamp < _lastKnownTimestamp) return;
    _buffer.add(message);
    _scheduleFlush();
  }

  // =========================
  // BATCHING
  // =========================

  void _scheduleFlush() {
    // ✅ FIX 2: no bloquear schedule si está flushing,
    // el flush al terminar revisará si hay más en el buffer
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 200), _flushBuffer);
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;

    isFlushing = true;

    final batch = List<Message>.from(_buffer);
    _buffer.clear();

    // ✅ FIX 3: O(1) lookup con Set en vez de O(n) por cada mensaje
    final existingIds = _items.map((m) => m.id).toSet();

    final newMessages = batch
        .where((msg) => !existingIds.contains(msg.id))
        .toList();

    if (newMessages.isNotEmpty) {
      // Un solo insertAll en vez de N inserts individuales
      _items.insertAll(0, newMessages);

      // Actualizar timestamp con el mayor del batch
      _lastKnownTimestamp = newMessages.fold(
        _lastKnownTimestamp,
        (max, msg) => msg.messageTimestamp > max ? msg.messageTimestamp : max,
      );

      state = AsyncData(List.unmodifiable(_items));
    }

    isFlushing = false;

    // ✅ Si llegaron más mensajes mientras flusheábamos, procesar
    if (_buffer.isNotEmpty) _scheduleFlush();
  }

  void reset() {
    _newMessagesSub?.cancel();
    _newMessagesSub = null;

    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    isFlushing = false;

    _items.clear();
    _cursor = null;
    _hasMore = true;
    _isLoadingMore = false;
    _activeChatJid = null;
    _lastKnownTimestamp = 0;
    _activeFilter = const DateFilterTodayAndYesterday();

    state = const AsyncData([]);
  }

  void cancelStream() {
    _newMessagesSub?.cancel();
    _newMessagesSub = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    _buffer.clear();
    isFlushing = false;
  }
}
