import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_bubble_skeleton.dart';

class MessageListLoading extends StatelessWidget {
  final int itemCount;
  const MessageListLoading({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        reverse: true,
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        itemCount: itemCount,
        itemBuilder: (_, index) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: MessageBubbleSkeleton(index: index),
        ),
      ),
    );
  }
}
