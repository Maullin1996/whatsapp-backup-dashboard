import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Placeholder de carga: aproxima la forma de `JornadaMatchesSection` con
/// ganadores y dos coincidencias (el caso "completo" — igual que
/// `SummarySkeleton`, que también aproxima la variante más larga de su
/// tarjeta, no cada combinación posible). Medido contra la sección real en
/// `matches_skeleton_test.dart`, con una tolerancia pequeña y explícita.
class MatchesSkeleton extends StatelessWidget {
  const MatchesSkeleton({super.key});

  static const _sections = 3;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (var i = 0; i < _sections; i++) ...[
            const _SectionSkeleton(),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _SectionSkeleton extends StatelessWidget {
  const _SectionSkeleton();

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
          _Block(width: 90, height: 24),
          SizedBox(height: AppSpacing.sm),
          _Block(width: 220, height: 32),
          SizedBox(height: AppSpacing.sm),
          _MatchTileSkeleton(),
          SizedBox(height: AppSpacing.sm),
          _MatchTileSkeleton(),
          SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// `_MatchTile` real tiene forma distinta en móvil (apilado, más alto) y
/// escritorio (una fila, más bajo) — ver `jornada_matches_section.dart`. El
/// skeleton necesita la misma rama para que la altura siga aproximando la
/// real en ambos anchos (`matches_skeleton_test.dart` compara a 360 y 1280).
class _MatchTileSkeleton extends StatelessWidget {
  const _MatchTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: _MatchTileSkeletonMobile(),
      desktop: _MatchTileSkeletonDesktop(),
    );
  }
}

/// Aproxima `_MatchTileMobile`: fila (número + hora), remitente, grupo,
/// chatJid y botón, todo apilado.
class _MatchTileSkeletonMobile extends StatelessWidget {
  const _MatchTileSkeletonMobile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.tileAll,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Block(width: 50, height: 28),
              Spacer(),
              _Block(width: 50, height: 14),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          _Block(width: 90, height: 22),
          SizedBox(height: AppSpacing.xs),
          _Block(width: 180, height: 24),
          SizedBox(height: AppSpacing.xs),
          _Block(width: 150, height: 20),
          SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: _Block(width: 64, height: 46),
          ),
        ],
      ),
    );
  }
}

/// Aproxima `_MatchTileDesktop`: número, remitente, grupo con su chatJid en
/// dos líneas, hora y botón, todo en una fila.
class _MatchTileSkeletonDesktop extends StatelessWidget {
  const _MatchTileSkeletonDesktop();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.tileAll,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Block(width: 50, height: 24),
          SizedBox(width: AppSpacing.md),
          Expanded(flex: 2, child: _Block(width: double.infinity, height: 18)),
          SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Block(width: double.infinity, height: 18),
                SizedBox(height: AppSpacing.xs),
                _Block(width: 110, height: 14),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          _Block(width: 50, height: 14),
          SizedBox(width: AppSpacing.sm),
          _Block(width: 64, height: 46),
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
