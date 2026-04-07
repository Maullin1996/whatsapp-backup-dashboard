import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/chat_list.dart';
import 'package:whatsapp_monitor_viewer/features/home/presentation/widgets/custom_message_group.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/chat_drawer.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/chat_header.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_list.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  static const double _mobileBreakpoint = 700;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeChat = ref.watch(activeChatProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;
        final chatListWidth = (constraints.maxWidth * 0.34)
            .clamp(320.0, 420.0)
            .toDouble();

        return PopScope<Object?>(
          canPop: !isMobile || activeChat == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isMobile && activeChat != null) {
              ref.read(activeChatProvider.notifier).clear();
            }
          },
          child: Scaffold(
            backgroundColor: const Color.fromARGB(255, 240, 239, 236),
            endDrawer: const ChatDrawer(),
            body: SafeArea(
              child: isMobile
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: activeChat == null
                          ? const ColoredBox(
                              key: ValueKey('mobile-chat-list'),
                              color: Colors.white,
                              child: ChatList(),
                            )
                          : _MobileConversationView(
                              key: const ValueKey('mobile-conversation'),
                              title: activeChat.groupName,
                            ),
                    )
                  : Row(
                      children: [
                        Container(
                          color: Colors.white,
                          width: chatListWidth,
                          child: const ChatList(),
                        ),
                        const VerticalDivider(
                          width: 1,
                          color: Color.fromARGB(16, 0, 0, 0),
                        ),
                        const Expanded(child: _DesktopConversationPanel()),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _DesktopConversationPanel extends ConsumerWidget {
  const _DesktopConversationPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(activeChatProvider);

    return ColoredBox(
      color: const Color.fromARGB(255, 240, 239, 236),
      child: chat == null
          ? const _EmptyConversationView()
          : const _ConversationView(),
    );
  }
}

class _ConversationView extends StatelessWidget {
  const _ConversationView({this.header});

  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        header ?? const ChatHeader(),
        const Expanded(child: MessageList()),
      ],
    );
  }
}

class _EmptyConversationView extends StatelessWidget {
  const _EmptyConversationView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const contentMaxWidth = 420.0;

        final sidePadding = constraints.maxWidth > contentMaxWidth
            ? (constraints.maxWidth - contentMaxWidth) / 2
            : 16.0;

        return Container(
          color: const Color.fromARGB(255, 240, 239, 236),
          padding: EdgeInsets.symmetric(horizontal: sidePadding),
          alignment: Alignment.center,
          child: const CustomMessageGroup(),
        );
      },
    );
  }
}

class _MobileConversationView extends ConsumerWidget {
  const _MobileConversationView({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      key: key,
      color: const Color.fromARGB(255, 240, 239, 236),
      child: _ConversationView(
        header: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Volver a chats',
                onPressed: () {
                  ref.read(activeChatProvider.notifier).clear();
                },
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Panel de control',
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openEndDrawer(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
