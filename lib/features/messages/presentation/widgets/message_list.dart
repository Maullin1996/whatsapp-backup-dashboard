import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_list_loading.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/helpers/format_day_label.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/message_list_scroll_controller.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/go_to_latest_message_button.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_appear_animation.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_bubble.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';

class MessageList extends ConsumerStatefulWidget {
  const MessageList({super.key});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  late final ScrollController _controller;
  bool _showGoToLatest = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
  }

  void _scrollToLatestMessage() {
    if (!_controller.hasClients) return;

    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
    );
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

    final shouldShow = _controller.offset > 200;

    if (shouldShow != _showGoToLatest) {
      _showGoToLatest = shouldShow;
      setState(() {});
    }

    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 200) {
      ref.read(messagesProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider);
    return state.when(
      data: (messages) {
        if (messages.isEmpty) {
          return Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: AssetImage('assets/images/fondo.png'),
              ),
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No hay mensajes aún',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Inicia una conversación para empezar',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              fit: BoxFit.cover,

              image: AssetImage('assets/images/fondo.png'),
            ),
          ),
          child: MessageListScrollController(
            scrollToLatest: _scrollToLatestMessage,
            child: Stack(
              children: [
                ListView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.only(bottom: 12),
                  reverse: true,
                  addAutomaticKeepAlives: false, // Añade esto
                  addRepaintBoundaries: true,
                  cacheExtent: 1000, // Aumenta el cache
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];

                    final prevMsg = index + 1 < messages.length
                        ? messages[index + 1]
                        : null;
                    final showSenderName =
                        prevMsg == null || prevMsg.senderName != msg.senderName;

                    final showDateSeparator =
                        prevMsg == null ||
                        DateTime.fromMillisecondsSinceEpoch(
                              msg.messageTimestamp,
                            ).toLocal().day !=
                            DateTime.fromMillisecondsSinceEpoch(
                              prevMsg.messageTimestamp,
                            ).toLocal().day;

                    return RepaintBoundary(
                      key: ValueKey(msg.id),
                      child: Column(
                        children: [
                          if (showDateSeparator)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE1F3FB),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  formatDayLabel(msg.messageTimestamp),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          MessageAppearAnimation(
                            index: index,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: showSenderName ? 10 : 2,
                                bottom: 12,
                                left: 12,
                                right: 12,
                              ),
                              child: MessageBubble(
                                message: msg,
                                showSenderName: showSenderName,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 20,
                  right: 20,

                  child: IgnorePointer(
                    ignoring: !_showGoToLatest,
                    child: AnimatedSlide(
                      offset: _showGoToLatest
                          ? Offset.zero
                          : const Offset(0, 0.25),
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _showGoToLatest ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        child: const GoToLatestMessageButton(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      error: (error, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
      loading: () => Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage('assets/images/fondo.png'),
          ),
        ),
        child: Center(child: const MessageListLoading()),
      ),
    );
  }
}
