import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Placeholder de carga: un encabezado de grupo y tarjetas de jornada con la
/// forma de `JornadaSummaryCard`.
class SummarySkeleton extends StatelessWidget {
  const SummarySkeleton({super.key});

  static const _cards = 3;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          const _Block(width: 140, height: 16),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < _cards; i++) ...[
            const _CardSkeleton(),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Block(width: 90, height: 16),
              _Block(width: 110, height: 22),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          _Block(width: 220, height: 12),
          SizedBox(height: AppSpacing.sm),
          _Block(width: 200, height: 12),
          // Línea del aviso de imágenes sin registrar.
          SizedBox(height: AppSpacing.sm),
          _Block(width: 170, height: 12),
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
