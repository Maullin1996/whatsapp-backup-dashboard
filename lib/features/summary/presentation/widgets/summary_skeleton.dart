import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Placeholder de carga con la forma del Resumen: una lista de tarjetas de
/// grupo, cada una con su nombre y las dos tarjetas de rol (como
/// `SummaryGroupTile`).
class SummarySkeleton extends StatelessWidget {
  const SummarySkeleton({super.key});

  static const _tiles = 4;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: _tiles,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (_, _) => const _TileSkeleton(),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Block(width: 140, height: 18),
              _Block(width: 90, height: 22),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _RoleSkeleton()),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _RoleSkeleton()),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleSkeleton extends StatelessWidget {
  const _RoleSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.tileAll,
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Block(width: 70, height: 14),
          SizedBox(height: AppSpacing.sm),
          _Block(width: 100, height: 22),
          SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _Block(width: 50, height: 20, radius: AppRadius.pill),
              SizedBox(width: AppSpacing.xs),
              _Block(width: 50, height: 20, radius: AppRadius.pill),
            ],
          ),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _Block({
    required this.width,
    required this.height,
    this.radius = AppRadius.thumbnail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
