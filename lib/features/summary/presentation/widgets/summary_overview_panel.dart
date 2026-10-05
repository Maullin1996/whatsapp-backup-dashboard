import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/summary_overview.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_pesos.dart';

/// Panel informativo del Resumen: un titular con lo más urgente del día, una
/// barra con la proporción de jornadas por estado y una tarjeta por cifra
/// (descuadres, pendientes, imágenes sin registrar, cuadran). Cada tarjeta
/// filtra la lista de jornadas; tocar la activa quita el filtro.
class SummaryOverviewPanel extends StatelessWidget {
  final SummaryOverview overview;
  final SummaryFilter filter;
  final ValueChanged<SummaryFilter> onFilter;

  const SummaryOverviewPanel({
    super.key,
    required this.overview,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final tiles = [
      _StatTile(
        label: 'Descuadres',
        value: o.descuadres,
        detail: o.descuadres > 0
            ? '${formatPesos(o.totalDiferencias)} en diferencias'
            : 'Sin diferencias de dinero',
        icon: Icons.warning_amber_rounded,
        color: AppColors.errorMessage,
        selected: filter == SummaryFilter.descuadre,
        onTap: () => onFilter(SummaryFilter.descuadre),
      ),
      _StatTile(
        label: 'Pendientes',
        value: o.pendientes,
        detail: o.pendientes > 0
            ? 'Falta Revisor o Sumador'
            : 'Todos registraron',
        icon: Icons.hourglass_top_rounded,
        color: AppColors.warning,
        selected: filter == SummaryFilter.pendiente,
        onTap: () => onFilter(SummaryFilter.pendiente),
      ),
      _StatTile(
        label: 'Imágenes sin registrar',
        value: o.imagenesSinRegistrar,
        detail: o.jornadasConImagenes == 1
            ? 'En 1 jornada terminada'
            : 'En ${o.jornadasConImagenes} jornadas terminadas',
        icon: Icons.image_not_supported_outlined,
        color: AppColors.accentTeal,
        selected: filter == SummaryFilter.imagenes,
        onTap: () => onFilter(SummaryFilter.imagenes),
      ),
      _StatTile(
        label: 'Cuadran',
        value: o.cuadran,
        detail: 'De ${o.jornadas} ${o.jornadas == 1 ? 'jornada' : 'jornadas'}',
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
        selected: filter == SummaryFilter.cuadra,
        onTap: () => onFilter(SummaryFilter.cuadra),
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Headline(overview: o),
            const SizedBox(height: AppSpacing.md),
            _StatusBar(overview: o),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                // 4 en fila en pantallas anchas; 2 x 2 en celular.
                final columns = constraints.maxWidth >= AppBreakpoints.mobile
                    ? 4
                    : 2;
                return _TileGrid(columns: columns, children: tiles);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lo más urgente del día en una frase: descuadres, luego pendientes, luego
/// "todo cuadra". Debajo, cuántas jornadas y grupos hay.
class _Headline extends StatelessWidget {
  final SummaryOverview overview;

  const _Headline({required this.overview});

  static String _jornadas(int n) => n == 1 ? '1 jornada' : '$n jornadas';

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final (text, icon, color) = o.descuadres > 0
        ? (
            o.descuadres == 1
                ? 'Hay 1 jornada con descuadre'
                : 'Hay ${o.descuadres} jornadas con descuadre',
            Icons.error_rounded,
            AppColors.errorMessage,
          )
        : o.pendientes > 0
        ? (
            '${_jornadas(o.pendientes)} sin registro completo',
            Icons.hourglass_top_rounded,
            AppColors.warning,
          )
        : (
            'Todas las jornadas cuadran',
            Icons.verified_rounded,
            AppColors.success,
          );

    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Icon(icon, color: color),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: AppTypography.headerTitle(
                  context,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                '${_jornadas(o.jornadas)} · '
                '${o.grupos} ${o.grupos == 1 ? 'grupo' : 'grupos'}',
                style: AppTypography.timestamp(
                  context,
                ).copyWith(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Barra con la proporción de jornadas con descuadre (rojo), pendientes
/// (ámbar) y que cuadran (verde).
class _StatusBar extends StatelessWidget {
  final SummaryOverview overview;

  const _StatusBar({required this.overview});

  @override
  Widget build(BuildContext context) {
    final segments = [
      (overview.descuadres, AppColors.errorMessage),
      (overview.pendientes, AppColors.warning),
      (overview.cuadran, AppColors.success),
    ].where((s) => s.$1 > 0);

    return ClipRRect(
      borderRadius: AppRadius.pillAll,
      child: SizedBox(
        height: AppSpacing.sm,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (count, color) in segments)
              Expanded(
                flex: count,
                child: ColoredBox(color: color),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjetas en filas de [columns], todas del mismo alto dentro de la fila.
class _TileGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const _TileGrid({required this.columns, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      if (rows.isNotEmpty) rows.add(const SizedBox(height: AppSpacing.sm));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var j = i; j < i + columns; j++) ...[
                if (j > i) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: j < children.length
                      ? children[j]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// Una cifra del panel. Con valor 0 queda en gris (nada que atender); con
/// [selected] lleva el borde del color de la cifra.
class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  final String detail;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = value > 0;
    final tone = active ? color : Colors.grey.shade500;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.10)
            : (active ? color.withValues(alpha: 0.04) : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.tileAll,
          side: BorderSide(
            color: selected ? color : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: tone),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.badge.copyWith(
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '$value',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.merge(AppTypography.tabular)
                      .copyWith(fontWeight: FontWeight.w800, color: tone),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.timestamp(
                    context,
                  ).copyWith(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
