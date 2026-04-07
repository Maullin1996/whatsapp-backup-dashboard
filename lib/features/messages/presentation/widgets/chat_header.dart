// lib/features/messages/presentation/widgets/chat_header.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/date_filter_provider.dart';

class ChatHeader extends ConsumerWidget {
  const ChatHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chat = ref.watch(activeChatProvider);
    final filter = ref.watch(dateFilterProvider);

    if (chat == null) return const SizedBox.shrink();

    final isFiltered = !filter.isDefault;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.black.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              chat.groupName,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          // Badge filtro activo
          if (isFiltered)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => ref.read(dateFilterProvider.notifier).reset(),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ],
              ),
            ),
          // Botón que abre el drawer
          IconButton(
            tooltip: 'Panel de control',
            icon: Icon(
              Icons.menu,
              color: isFiltered ? const Color(0xFF00897B) : Colors.black54,
            ),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
    );
  }
}
