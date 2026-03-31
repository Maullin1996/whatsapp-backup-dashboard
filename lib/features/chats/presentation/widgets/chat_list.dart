//chat_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/chats_loading_view.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/chat_search_query_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/chat_appear_animation.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/custom_popup_menu_logout_button.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_time.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/chats_provider.dart';

class ChatList extends ConsumerWidget {
  const ChatList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatsProvider);
    final activeChat = ref.watch(activeChatProvider);

    return Column(
      children: [
        _ChatHeader(),
        _ChateSearchBar(),
        state.when(
          loading: () => const Expanded(child: ChatsListLoading()),
          error: (error, _) =>
              Expanded(child: Center(child: Text(mapFailureToMessage(error)))),
          data: (chats) => Expanded(
            child: Column(
              children: [
                _ChatSearchResults(chats: chats, activeChat: activeChat),
                Expanded(
                  child: _ChatMainList(activeChat: activeChat, chats: chats),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Text(
            'Monitor de Imagenes',
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
              fontSize: 24,
            ),
          ),
          const Spacer(),
          CustomPopupMenuLogoutButton(),
        ],
      ),
    );
  }
}

class _ChateSearchBar extends ConsumerStatefulWidget {
  const _ChateSearchBar();

  @override
  ConsumerState<_ChateSearchBar> createState() => _ChateSearchBarState();
}

class _ChateSearchBarState extends ConsumerState<_ChateSearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(() {
      ref.read(chatSearchQueryProvider.notifier).state = _controller.text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatSearchQueryProvider, (previous, next) {
      if (_controller.text != next) {
        _controller.text = next;
      }
    });

    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Buscar grupo',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ChatSearchResults extends ConsumerWidget {
  final List<Chat> chats;
  final Chat? activeChat;
  const _ChatSearchResults({required this.chats, required this.activeChat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(chatSearchQueryProvider).trim().toLowerCase();

    if (query.isEmpty) {
      return const SizedBox.shrink();
    }

    final results = chats
        .where((chat) => chat.groupName.toLowerCase().contains(query))
        .toList();

    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text('No se encontraron grupos'),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final chat = results[index];
          final isActive = activeChat?.chatJid == chat.chatJid;
          return ChatAppearAnimation(
            child: CustonGroupContainer(
              isActive: isActive,
              chat: chat,
              time: formatTime(chat.lastMessageAt, context),
              onTap: () {
                ref.read(activeChatProvider.notifier).select(chat);
                ref.read(chatSearchQueryProvider.notifier).state = '';
              },
            ),
          );
        },
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemCount: results.length,
      ),
    );
  }
}

class _ChatMainList extends ConsumerWidget {
  final List<Chat> chats;
  final Chat? activeChat;

  const _ChatMainList({required this.activeChat, required this.chats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: chats.length,
      itemBuilder: (context, index) {
        final chat = chats[index];
        final isActive = activeChat?.chatJid == chat.chatJid;

        final time = formatTime(chat.lastMessageAt, context);

        return ChatAppearAnimation(
          child: CustonGroupContainer(
            isActive: isActive,
            chat: chat,
            time: time,
            onTap: () {
              ref.read(activeChatProvider.notifier).select(chat);
              ref.read(chatSearchQueryProvider.notifier).state = '';
            },
          ),
        );
      },
    );
  }
}

class CustonGroupContainer extends StatefulWidget {
  const CustonGroupContainer({
    super.key,
    required this.isActive,
    required this.chat,
    required this.time,
    this.onTap,
  });

  final bool isActive;
  final Chat chat;
  final String time;
  final GestureTapCallback? onTap;

  @override
  State<CustonGroupContainer> createState() => _CustonGroupContainerState();
}

class _CustonGroupContainerState extends State<CustonGroupContainer> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final baseColor = widget.isActive
        ? const Color.fromARGB(159, 236, 234, 234)
        : Colors.transparent;
    final hoverColor = const Color.fromARGB(
      255,
      133,
      131,
      131,
    ).withValues(alpha: 0.15);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: _hovered ? hoverColor : baseColor,
              borderRadius: BorderRadius.circular(12),
            ),

            child: Row(
              children: [
                ClipOval(
                  child: Image.asset(
                    'assets/images/blank-profile.png',
                    width: 55,
                    fit: BoxFit.cover,
                    cacheWidth: 110,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.chat.groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            widget.time,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.chat.totalImages} mensajes',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
