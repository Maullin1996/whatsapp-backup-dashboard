import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Placeholder de carga con la forma de la lista de Coincidencias: tarjetas de
/// grupo (icono, nombre y cantidad de ganadores), como `GroupMatchesTile`.
class MatchesSkeleton extends StatelessWidget {
  const MatchesSkeleton({super.key});

  static const _tiles = 5;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _tiles,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
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
      child: const Row(
        children: [
          _Block(width: 24, height: 24),
          SizedBox(width: AppSpacing.md),
          Expanded(child: _Block(width: double.infinity, height: 20)),
          SizedBox(width: AppSpacing.md),
          _Block(width: 90, height: 28),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  final double width;
  final double height;

  const _Block({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
      ),
    );
  }
}
