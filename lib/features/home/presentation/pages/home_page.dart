import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/chat_list.dart';
import 'package:whatsapp_monitor_viewer/features/home/presentation/widgets/custom_message_group.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/chat_drawer.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/chat_header.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_list.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeChat = ref.watch(activeChatProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AppBreakpoints.homeSplit;
        final chatListWidth = AppSizes.chatListWidth(constraints.maxWidth);

        return PopScope<Object?>(
          canPop: !isMobile || activeChat == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop && isMobile && activeChat != null) {
              ref.read(activeChatProvider.notifier).clear();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.screenBackground,
            endDrawer: const ChatDrawer(),
            body: SafeArea(
              child: isMobile
                  ? AnimatedSwitcher(
                      duration: AppDurations.pageTransition,
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
      color: AppColors.screenBackground,
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
        const contentMaxWidth = AppSizes.emptyStateMaxWidth;

        final sidePadding = constraints.maxWidth > contentMaxWidth
            ? (constraints.maxWidth - contentMaxWidth) / 2
            : AppSpacing.lg;

        return Container(
          color: AppColors.screenBackground,
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
      color: AppColors.screenBackground,
      child: _ConversationView(
        header: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
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
                  style: AppTypography.headerTitle(context),
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
