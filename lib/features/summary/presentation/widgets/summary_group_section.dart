import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/jornada_summary_card.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_status_pill.dart';

/// Los grupos del Resumen en una cuadrícula tipo mosaico: 1 columna en
/// celular y hasta 3 en pantallas anchas (según
/// [AppSizes.summaryGroupMinWidth]). Cada grupo va a la columna que lleva
/// menos alto acumulado, así que el orden de lectura (izquierda a derecha,
/// arriba a abajo) respeta el orden de [groups] y no quedan huecos aunque un
/// grupo tenga más jornadas que otro.
class SummaryGroupGrid extends StatelessWidget {
  final List<List<JornadaSummary>> groups;
  final DateTime now;

  const SummaryGroupGrid({super.key, required this.groups, required this.now});

  static const _gap = AppSpacing.md;

  /// Alto aproximado de un grupo, en unidades relativas: la cabecera y, por
  /// jornada, su bloque más sus avisos.
  int _weight(List<JornadaSummary> group) =>
      2 +
      group.fold(
        0,
        (sum, j) => sum + 6 + JornadaSummaryCard.noticeCount(j, now),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + _gap) ~/
                    (AppSizes.summaryGroupMinWidth + _gap))
                .clamp(1, 3);

        final sections = [
          for (final group in groups)
            SummaryGroupSection(jornadas: group, now: now),
        ];
        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < sections.length; i++) ...[
                if (i > 0) const SizedBox(height: _gap),
                sections[i],
              ],
            ],
          );
        }

        final heights = List.filled(columns, 0);
        final byColumn = List.generate(columns, (_) => <Widget>[]);
        for (var i = 0; i < groups.length; i++) {
          var target = 0;
          for (var c = 1; c < columns; c++) {
            if (heights[c] < heights[target]) target = c;
          }
          heights[target] += _weight(groups[i]);
          byColumn[target].add(sections[i]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var c = 0; c < columns; c++) ...[
              if (c > 0) const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < byColumn[c].length; i++) ...[
                      if (i > 0) const SizedBox(height: _gap),
                      byColumn[c][i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tarjeta de un grupo: su nombre con un conteo por estado y, debajo, sus
/// jornadas una tras otra separadas por un divisor.
class SummaryGroupSection extends StatelessWidget {
  final List<JornadaSummary> jornadas;
  final DateTime now;

  const SummaryGroupSection({
    super.key,
    required this.jornadas,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _GroupHeader(jornadas: jornadas),
            for (final summary in jornadas) ...[
              Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
              JornadaSummaryCard(summary: summary, now: now),
            ],
          ],
        ),
      ),
    );
  }
}

/// Nombre del grupo y cuántas jornadas tiene en cada estado (solo los
/// estados presentes). Si todas cuadran, una sola pastilla verde.
class _GroupHeader extends StatelessWidget {
  final List<JornadaSummary> jornadas;

  const _GroupHeader({required this.jornadas});

  static String _count(int n, String singular, String plural) =>
      '$n ${n == 1 ? singular : plural}';

  @override
  Widget build(BuildContext context) {
    var descuadres = 0, pendientes = 0;
    for (final j in jornadas) {
      switch (j.estado) {
        case JornadaDescuadre():
          descuadres++;
        case JornadaPendiente():
          pendientes++;
        case JornadaCuadra():
          break;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.groups_rounded,
                size: 20,
                color: AppColors.accentTeal,
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  jornadas.first.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentTeal,
                  ),
                ),
              ),
            ],
          ),
          if (descuadres > 0)
            SummaryStatusPill(
              label: _count(descuadres, 'descuadre', 'descuadres'),
              icon: Icons.warning_amber_rounded,
              color: AppColors.errorMessage,
            ),
          if (pendientes > 0)
            SummaryStatusPill(
              label: _count(pendientes, 'pendiente', 'pendientes'),
              icon: Icons.hourglass_top_rounded,
              color: AppColors.warning,
            ),
          if (descuadres == 0 && pendientes == 0)
            const SummaryStatusPill(
              label: 'Todo cuadra',
              icon: Icons.check_circle_rounded,
              color: AppColors.success,
            ),
        ],
      ),
    );
  }
}
