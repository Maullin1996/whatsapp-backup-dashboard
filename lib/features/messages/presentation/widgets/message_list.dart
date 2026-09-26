import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/pending_upload_indicators.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_list_loading.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/helpers/format_day_label.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/message_list_scroll_controller.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/go_to_latest_message_button.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_appear_animation.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_bubble.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';

class _MessageListItem {
  final Message message;
  final bool showSenderName;
  final bool showDateSeparator;

  const _MessageListItem({
    required this.message,
    required this.showSenderName,
    required this.showDateSeparator,
  });
}

class MessageList extends ConsumerStatefulWidget {
  const MessageList({super.key});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  static const _backgroundDecoration = BoxDecoration(
    image: DecorationImage(
      fit: BoxFit.cover,
      image: AssetImage('assets/images/fondo.png'),
    ),
  );

  /// Margen (20, el del `Positioned` de `_GoToLatestButton`) y tamaño (FAB
  /// estándar) del botón "ir al último mensaje": los indicadores de subida
  /// van justo encima de ese hueco.
  static const _floatingButtonMargin = 20.0;
  static const _floatingButtonSize = 56.0;

  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_onScroll);
  }

  void _scrollToLatestMessage() {
    if (!_controller.hasClients) return;

    _controller.animateTo(
      0.0,
      duration: AppDurations.scrollToLatest,
      curve: Curves.easeOut,
    );
  }

  void _onScroll() {
    if (!_controller.hasClients) return;

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
            decoration: _backgroundDecoration,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: 20,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.dialogAll,
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 80,
                      color: Colors.grey,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'No hay mensajes aún',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
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

        final screenWidth = MediaQuery.sizeOf(context).width;

        final items = List.generate(messages.length, (index) {
          final msg = messages[index];
          final prevMsg = index + 1 < messages.length
              ? messages[index + 1]
              : null;
          return _MessageListItem(
            message: msg,
            showSenderName:
                prevMsg == null || prevMsg.senderName != msg.senderName,
            showDateSeparator: prevMsg == null ||
                DateTime.fromMillisecondsSinceEpoch(msg.messageTimestamp)
                        .toLocal()
                        .day !=
                    DateTime.fromMillisecondsSinceEpoch(
                      prevMsg.messageTimestamp,
                    ).toLocal().day,
          );
        });

        return Container(
          decoration: _backgroundDecoration,
          child: MessageListScrollController(
            scrollToLatest: _scrollToLatestMessage,
            child: Stack(
              children: [
                ListView.builder(
                  controller: _controller,
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  reverse: true,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return RepaintBoundary(
                      key: ValueKey(item.message.id),
                      child: Column(
                        children: [
                          if (item.showDateSeparator)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE1F3FB),
                                  borderRadius: AppRadius.buttonAll,
                                ),
                                child: Text(
                                  formatDayLabel(item.message.messageTimestamp),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          MessageAppearAnimation(
                            index: index,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: item.showSenderName ? 10 : 2,
                                bottom: AppSpacing.md,
                                left: AppSpacing.md,
                                right: AppSpacing.md,
                              ),
                              child: MessageBubble(
                                message: item.message,
                                showSenderName: item.showSenderName,
                                screenWidth: screenWidth,
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
                  child: _GoToLatestButton(controller: _controller),
                ),
                const Positioned(
                  bottom:
                      _floatingButtonMargin +
                      _floatingButtonSize +
                      AppSpacing.md,
                  right: _floatingButtonMargin,
                  child: PendingUploadIndicators(),
                ),
              ],
            ),
          ),
        );
      },
      error: (error, _) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
      loading: () => Container(
        decoration: _backgroundDecoration,
        child: const Center(child: MessageListLoading()),
      ),
    );
  }
}

class _GoToLatestButton extends StatefulWidget {
  final ScrollController controller;
  const _GoToLatestButton({required this.controller});

  @override
  State<_GoToLatestButton> createState() => _GoToLatestButtonState();
}

class _GoToLatestButtonState extends State<_GoToLatestButton> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final shouldShow = widget.controller.offset > 200;
    if (shouldShow != _show) {
      setState(() => _show = shouldShow);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_show,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.25),
        duration: AppDurations.pageTransition,
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _show ? 1.0 : 0.0,
          duration: AppDurations.fadeOut,
          child: const GoToLatestMessageButton(),
        ),
      ),
    );
  }
}
