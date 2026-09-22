import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

class ChatsListLoading extends StatelessWidget {
  final int itemCount;
  const ChatsListLoading({super.key, this.itemCount = 12});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (_, _) => const _ChatSkeletonTile(),
      ),
    );
  }
}

class _ChatSkeletonTile extends StatelessWidget {
  const _ChatSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
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
                      child: Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppRadius.thumbnail,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      width: 48,
                      height: AppSpacing.md,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppRadius.thumbnail,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: 120,
                  height: AppSpacing.md,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
