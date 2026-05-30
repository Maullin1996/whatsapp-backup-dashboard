import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/messages_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/date_filter_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/firestore_providers.dart';
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

  // ✅ Caché de IDs ya consultados y editados
  final Set<String> _checkedIds = {};
  final Set<String> _editedIds = {};

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

  // ==================================================
  // 🔀 SORT ESTABLE
  // ==================================================
  List<Message> _sortMessages(List<Message> messages) {
    final sorted = List<Message>.from(messages);
    sorted.sort((a, b) {
      final tsCmp = b.messageTimestamp.compareTo(a.messageTimestamp);
      if (tsCmp != 0) return tsCmp;

      // Empate de timestamp: desempatar con shiftImageIndex si existe
      final aIdx = a.shiftImageIndex;
      final bIdx = b.shiftImageIndex;

      if (aIdx != null && bIdx != null) {
        return bIdx.compareTo(aIdx);
      }

      // Fallback: por id alfabético
      return b.id.compareTo(a.id);
    });
    return sorted;
  }

  // ==================================================
  // ✅ CRUCE CON EDIT_ATTEMPTS CON CACHÉ
  // ==================================================
  Future<List<Message>> _enrichWithEdits(List<Message> messages) async {
    final uncheckedIds = messages
        .map((m) => m.id)
        .where((id) => !_checkedIds.contains(id))
        .toList();

    if (uncheckedIds.isNotEmpty) {
      final datasource = ref.read(editAttemptsDatasourceProvider);
      final newEditedIds = await datasource.fetchEditedMessageIds(uncheckedIds);

      _checkedIds.addAll(uncheckedIds);
      _editedIds.addAll(newEditedIds);
    }

    return messages.map((m) {
      if (_editedIds.contains(m.id)) {
        return Message(
          id: m.id,
          chatJid: m.chatJid,
          senderName: m.senderName,
          hasMedia: m.hasMedia,
          messageTimestamp: m.messageTimestamp,
          localTime: m.localTime,
          caption: m.caption,
          storagePath: m.storagePath,
          shift: m.shift,
          messageDate: m.messageDate,
          isEdited: true,
          shiftImageIndex: m.shiftImageIndex,
        );
      }
      return m;
    }).toList();
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

    await result.fold(
      (failure) async {
        state = AsyncError(failure, StackTrace.current);
      },
      (MessagesPage page) async {
        final enriched = await _enrichWithEdits(page.items);
        final sorted = _sortMessages(enriched); // 👈

        _items
          ..clear()
          ..addAll(sorted);
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

  // ==================================================
  // PAGINACIÓN
  // ==================================================
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

    await result.fold(
      (failure) async {
        _isLoadingMore = false;
      },
      (page) async {
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;

        if (page.items.isNotEmpty) {
          final enriched = await _enrichWithEdits(page.items);
          _items.addAll(_sortMessages(enriched)); // 👈
          state = AsyncData(List.unmodifiable(_items));
        }
        _isLoadingMore = false;
      },
    );
  }

  // ==================================================
  // REALTIME
  // ==================================================
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
    if (message.messageTimestamp < _lastKnownTimestamp) return;
    _buffer.add(message);
    _scheduleFlush();
  }

  // ==================================================
  // BATCHING
  // ==================================================
  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 200), _flushBuffer);
  }

  void _flushBuffer() {
    if (_buffer.isEmpty) return;

    isFlushing = true;

    final batch = List<Message>.from(_buffer);
    _buffer.clear();

    final existingIds = _items.map((m) => m.id).toSet();
    final newMessages = batch
        .where((msg) => !existingIds.contains(msg.id))
        .toList();

    if (newMessages.isNotEmpty) {
      _items.insertAll(0, newMessages);

      _lastKnownTimestamp = newMessages.fold(
        _lastKnownTimestamp,
        (max, msg) => msg.messageTimestamp > max ? msg.messageTimestamp : max,
      );

      state = AsyncData(List.unmodifiable(_items));
    }

    isFlushing = false;

    if (_buffer.isNotEmpty) _scheduleFlush();
  }

  // ==================================================
  // RESET
  // ==================================================
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

    _checkedIds.clear();
    _editedIds.clear();

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
