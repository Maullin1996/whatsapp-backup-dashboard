//chat_list.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/chats_loading_view.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/chat_search_query_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/chat_appear_animation.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/widgets/custom_popup_menu_logout_button.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_time.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/chats_provider.dart';

const _avatarColors = [
  Color(0xFF25D366),
  Color(0xFF128C7E),
  Color(0xFF34B7F1),
  Color(0xFFFFC107),
  Color(0xFFFF5722),
  Color(0xFF9C27B0),
  Color(0xFFE91E63),
  Color(0xFF795548),
  Color(0xFF607D8B),
];

bool _isLight(Color color) {
  return color.computeLuminance() > 0.5;
}

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
          error: (error, _) => Expanded(
            child: SelectionArea(
              child: Center(child: Text(mapFailureToMessage(error))),
            ),
          ),
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
          const SizedBox(width: AppSpacing.md),
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: TextFormField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: 'Buscar grupo',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Colors.grey.shade200,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.search),
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

    if (query.isEmpty) return const SizedBox.shrink();

    final results = chats
        .where((chat) => chat.groupName.toLowerCase().contains(query))
        .toList();

    if (results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.sm),
        child: Text('No se encontraron grupos'),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: AppRadius.tileAll,
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemBuilder: (context, index) {
          final chat = results[index];
          final isActive = activeChat?.chatJid == chat.chatJid;
          return ChatAppearAnimation(
            index: index,
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
    final items = [
      for (final chat in chats)
        (chat: chat, time: formatTime(chat.lastMessageAt, context)),
    ];

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final (:chat, :time) = items[index];
        final isActive = activeChat?.chatJid == chat.chatJid;

        return ChatAppearAnimation(
          index: index,
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
  late final Color _bgColor;
  late final Color _textColor;
  late final String _initial;

  @override
  void initState() {
    super.initState();
    _bgColor = _avatarColors[widget.chat.groupName.hashCode % _avatarColors.length];
    _textColor = _isLight(_bgColor) ? Colors.black : Colors.white;
    _initial = widget.chat.groupName.isNotEmpty
        ? widget.chat.groupName[0].toUpperCase()
        : '?';
  }

  @override
  Widget build(BuildContext context) {
    return _HoverBackground(
      isActive: widget.isActive,
      onTap: widget.onTap,
      child: Row(
        children: [
          CircleAvatar(
            radius: AppSizes.chatAvatarRadius,
            backgroundColor: _bgColor,
            child: Text(
              _initial,
              style: AppTypography.avatarInitials.copyWith(color: _textColor),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
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
                        style: AppTypography.chatTileTitle,
                      ),
                    ),
                    Text(
                      widget.time,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${widget.chat.totalImages} mensajes',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverBackground extends StatefulWidget {
  final bool isActive;
  final Widget child;
  final GestureTapCallback? onTap;

  const _HoverBackground({
    required this.isActive,
    required this.child,
    this.onTap,
  });

  @override
  State<_HoverBackground> createState() => _HoverBackgroundState();
}

class _HoverBackgroundState extends State<_HoverBackground> {
  bool _hovered = false;

  static final _hoverColor =
      const Color.fromARGB(255, 133, 131, 131).withValues(alpha: 0.15);

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isActive ? AppColors.activeTile : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppDurations.hover,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: _hovered ? _hoverColor : bgColor,
              borderRadius: AppRadius.cardAll,
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
