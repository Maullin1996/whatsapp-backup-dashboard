// lib/features/messages/presentation/widgets/chat_header.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: kIsWeb
                ? SelectableText(
                    chat.groupName,
                    maxLines: 1,
                    style: AppTypography.headerTitle(context),
                  )
                : Text(
                    chat.groupName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headerTitle(context),
                  ),
          ),
          // Badge filtro activo
          if (isFiltered)
            Container(
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.12),
                borderRadius: AppRadius.pillAll,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    filter.label,
                    style: AppTypography.badge.copyWith(
                      color: AppColors.accentTeal,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  GestureDetector(
                    onTap: () => ref.read(dateFilterProvider.notifier).reset(),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: AppColors.accentTeal,
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
              color: isFiltered ? AppColors.accentTeal : Colors.black54,
            ),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
      ),
    );
  }
}
