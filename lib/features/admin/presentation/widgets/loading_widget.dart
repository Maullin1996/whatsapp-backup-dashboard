import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const ResponsiveLayout(
      mobile: _LoadingWidgetMobile(),
      desktop: _LoadingWidgetDesktop(),
    );
  }
}

class _LoadingWidgetMobile extends StatelessWidget {
  const _LoadingWidgetMobile();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.adminPanelMaxWidth),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: 8,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, _) => const _ShimmerCard(isMobile: true),
        ),
      ),
    );
  }
}

class _LoadingWidgetDesktop extends StatelessWidget {
  const _LoadingWidgetDesktop();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.adminPanelMaxWidth),
        child: ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.xl),
          itemCount: 8,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (_, _) => const _ShimmerCard(isMobile: false),
        ),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final bool isMobile;
  const _ShimmerCard({required this.isMobile});

  /// Botones que hoy puede mostrar `_UserCard` como máximo (contraseña,
  /// grupos, "Asignar revisión", rol, eliminar) — igual en mobile (apilados)
  /// y desktop (`Wrap`). El rediseño de roles (selector de rol simple +
  /// botón "Horarios" en `AssignGroupsDialog`) puede volver a cambiar esta
  /// cantidad/disposición: revisar este skeleton cuando llegue esa tarea.
  static const int _maxButtons = 5;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        key: const ValueKey('shimmerCard'),
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.cardAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: isMobile ? 40 : 48,
                  height: isMobile ? 40 : 48,
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
                      Container(
                        key: const ValueKey('shimmerTitleLine'),
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        key: const ValueKey('shimmerSubtitleLine'),
                        height: 10,
                        width: 160,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.skeletonCard),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _chip(80, key: const ValueKey('shimmerGroupChip_0')),
                const SizedBox(width: 6),
                _chip(100, key: const ValueKey('shimmerGroupChip_1')),
                const SizedBox(width: 6),
                _chip(60, key: const ValueKey('shimmerGroupChip_2')),
              ],
            ),
            const SizedBox(height: 10),
            // Equivalente a `_ReviewAssignmentStatus`: el skeleton no sabe
            // quién mira, así que la muestra siempre (a diferencia del real,
            // que solo aparece para un viewer superAdmin) — es una
            // aproximación de alto, no una réplica de la lógica de visibilidad.
            Container(
              key: const ValueKey('shimmerStatusLine'),
              height: 10,
              width: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.thumbnail),
              ),
            ),
            const SizedBox(height: 10),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < _maxButtons; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.xs),
                        _buttonPlaceholder(index: i, height: 36),
                      ],
                    ],
                  )
                : Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (var i = 0; i < _maxButtons; i++)
                        _buttonPlaceholder(index: i, width: 120, height: 28),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _chip(double width, {required Key key}) {
    return Container(
      key: key,
      height: 28,
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.skeletonCard),
      ),
    );
  }

  Widget _buttonPlaceholder({
    required int index,
    double? width,
    required double height,
  }) {
    return Container(
      key: ValueKey('shimmerButtonPlaceholder_$index'),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.skeletonCard),
      ),
    );
  }
}
