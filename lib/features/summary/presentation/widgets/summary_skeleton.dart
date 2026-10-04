import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Placeholder de carga con la forma del Resumen: el panel informativo
/// (titular, barra y cifras) y tarjetas de grupo con la forma de
/// `SummaryGroupSection` (nombre y dos jornadas), en las mismas columnas que
/// `SummaryGroupGrid`.
class SummarySkeleton extends StatelessWidget {
  const SummarySkeleton({super.key});

  static const _cards = 3;
  static const _gap = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth - 2 * AppSpacing.md;
          final tiles = width >= AppBreakpoints.mobile ? 4 : 2;
          final columns =
              ((width + _gap) ~/ (AppSizes.summaryGroupMinWidth + _gap)).clamp(
                1,
                3,
              );

          return ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _Panel(tiles: tiles),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (var i = 0; i < _cards; i++)
                    SizedBox(
                      width: (width - _gap * (columns - 1)) / columns,
                      child: const _CardSkeleton(),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final int tiles;

  const _Panel({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _Block(width: 40, height: 40, radius: 20),
              SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: 200, height: 16),
                  SizedBox(height: AppSpacing.xs),
                  _Block(width: 120, height: 12),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _Block(width: double.infinity, height: AppSpacing.sm),
          const SizedBox(height: AppSpacing.md),
          GridView.count(
            crossAxisCount: tiles,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
            children: [
              for (var i = 0; i < 4; i++)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.tileAll,
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
            ],
          ),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre del grupo y su pastilla.
          Row(
            children: [
              _Block(width: 120, height: 18),
              SizedBox(width: AppSpacing.sm),
              _Block(width: 90, height: 22),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          _JornadaSkeleton(),
          SizedBox(height: AppSpacing.lg),
          _JornadaSkeleton(),
        ],
      ),
    );
  }
}

/// Una jornada: nombre y estado, y la tabla (encabezado y dos roles).
class _JornadaSkeleton extends StatelessWidget {
  const _JornadaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
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
        _Block(width: double.infinity, height: 12),
        SizedBox(height: AppSpacing.sm),
        _Block(width: double.infinity, height: 12),
        SizedBox(height: AppSpacing.sm),
        _Block(width: double.infinity, height: 12),
      ],
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
