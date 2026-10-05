import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/imagenes_faltantes.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_status_pill.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_pesos.dart';

/// Una jornada de un grupo, dentro de la tarjeta del grupo
/// (`SummaryGroupSection`): cabecera con el estado (fondo teñido de su
/// color), una tabla compacta con Revisor y Sumador en filas (imágenes,
/// tickets y total en columnas) y debajo los avisos: quién registró de más si
/// hay descuadre e imágenes sin registrar.
///
/// [now] decide si la jornada ya terminó: solo entonces aparece el aviso
/// informativo de imágenes sin registrar; mientras no termina, la cabecera
/// dice "En curso".
class JornadaSummaryCard extends StatelessWidget {
  final JornadaSummary summary;
  final DateTime now;

  const JornadaSummaryCard({
    super.key,
    required this.summary,
    required this.now,
  });

  /// Avisos que muestra la jornada (descuadre e imágenes por rol): sirve
  /// para estimar su alto al repartir los grupos en columnas.
  static int noticeCount(JornadaSummary summary, DateTime now) =>
      (summary.estado is JornadaDescuadre ? 1 : 0) +
      [
        ReviewRole.revisor,
        ReviewRole.sumador,
      ].where((rol) => (imagenesFaltantes(summary, rol, now) ?? 0) > 0).length;

  @override
  Widget build(BuildContext context) {
    final estado = summary.estado;
    final (_, _, color) = summaryStatusStyle(estado);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(summary: summary, now: now, color: color),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ComparisonTable(
                revisor: summary.revisor,
                sumador: summary.sumador,
                descuadre: estado is JornadaDescuadre,
              ),
              if (estado is JornadaDescuadre) _DifferenceLine(summary: summary),
              for (final rol in ReviewRole.values)
                _MissingImagesLine(
                  rol: rol,
                  missing: imagenesFaltantes(summary, rol, now),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nombre corto de la jornada, su horario (y "En curso" si no ha terminado)
/// y la pastilla de estado, sobre un fondo levemente teñido del color del
/// estado. Si no cabe en una línea, la pastilla baja a la siguiente en vez
/// de recortarse.
class _Header extends StatelessWidget {
  final JornadaSummary summary;
  final DateTime now;
  final Color color;

  const _Header({
    required this.summary,
    required this.now,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final shift = shiftFromLabel(summary.shift);
    final enCurso =
        shift != null && !jornadaTerminada(summary.fechaJornada, shift, now);
    final hours = shiftHoursText(summary.shift);
    final subtitle = [?hours, if (enCurso) 'En curso'].join(' · ');

    return ColoredBox(
      color: color.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shortShiftName(summary.shift),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headerTitle(context),
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.timestamp(
                      context,
                    ).copyWith(color: Colors.grey.shade700),
                  ),
              ],
            ),
            SummaryStatusPill.of(summary.estado),
          ],
        ),
      ),
    );
  }
}

/// Revisor y Sumador en filas, con imágenes, tickets y total en columnas. Si
/// hay descuadre, la columna del total va en rojo. Un rol sin registrar
/// muestra "Sin registrar" bajo su nombre y guiones en sus cifras.
class _ComparisonTable extends StatelessWidget {
  final RoleSummary revisor;
  final RoleSummary sumador;
  final bool descuadre;

  const _ComparisonTable({
    required this.revisor,
    required this.sumador,
    required this.descuadre,
  });

  static const _empty = '—';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headerStyle = textTheme.bodySmall?.copyWith(
      color: Colors.grey.shade700,
    );
    final valueStyle = textTheme.bodyMedium?.merge(AppTypography.tabular);
    final totalStyle = valueStyle?.copyWith(
      fontWeight: FontWeight.w700,
      color: descuadre ? AppColors.errorMessage : null,
    );

    TableRow row(ReviewRole rol, RoleSummary role) {
      String value(String Function() format) =>
          role.registrado ? format() : _empty;
      return TableRow(
        children: [
          _RoleCell(rol: rol, summary: role),
          _Cell(
            Text(value(() => '${role.cantidadImagenes}'), style: valueStyle),
          ),
          _Cell(
            Text(value(() => '${role.cantidadTickets}'), style: valueStyle),
          ),
          _Cell(
            Text(value(() => formatPesos(role.totalSuma)), style: totalStyle),
          ),
        ],
      );
    }

    return Table(
      columnWidths: const {
        0: FlexColumnWidth(1.3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1),
        3: FlexColumnWidth(1.6),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const SizedBox.shrink(),
            _Cell(Text('Imágenes', style: headerStyle)),
            _Cell(Text('Tickets', style: headerStyle)),
            _Cell(Text('Total', style: headerStyle)),
          ],
        ),
        row(ReviewRole.revisor, revisor),
        row(ReviewRole.sumador, sumador),
      ],
    );
  }
}

/// Celda de cifra: alineada a la derecha y encogida si no cabe.
class _Cell extends StatelessWidget {
  final Widget child;

  const _Cell(this.child);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(fit: BoxFit.scaleDown, child: child),
      ),
    );
  }
}

class _RoleCell extends StatelessWidget {
  final ReviewRole rol;
  final RoleSummary summary;

  const _RoleCell({required this.rol, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rol.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (!summary.registrado)
            Text(
              'Sin registrar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.badge.copyWith(
                fontSize: 11,
                color: AppColors.warning,
              ),
            ),
        ],
      ),
    );
  }
}

/// Quién registró más dinero y por cuánto (el badge solo dice el monto).
class _DifferenceLine extends StatelessWidget {
  final JornadaSummary summary;

  const _DifferenceLine({required this.summary});

  @override
  Widget build(BuildContext context) {
    final diff = summary.revisor.totalSuma - summary.sumador.totalSuma;
    final (mayor, menor) = diff > 0
        ? (ReviewRole.revisor, ReviewRole.sumador)
        : (ReviewRole.sumador, ReviewRole.revisor);

    return _Notice(
      icon: Icons.compare_arrows_rounded,
      color: AppColors.errorMessage,
      text:
          'El ${mayor.label} registró ${formatPesos(diff.abs())} más que el '
          '${menor.label}',
    );
  }
}

/// Aviso informativo de un rol: cuántas imágenes de la jornada no registró.
/// Solo con [missing] > 0. Tono neutro (gris, nunca rojo: el rojo es del
/// descuadre de dinero) y solo la diferencia, no el total del contador.
class _MissingImagesLine extends StatelessWidget {
  final ReviewRole rol;
  final int? missing;

  const _MissingImagesLine({required this.rol, required this.missing});

  @override
  Widget build(BuildContext context) {
    final count = missing;
    if (count == null || count <= 0) return const SizedBox.shrink();

    return _Notice(
      icon: Icons.info_outline_rounded,
      color: Colors.grey.shade600,
      prefix: rol.label,
      text: count == 1
          ? 'Falta 1 imagen por registrar'
          : 'Faltan $count imágenes por registrar',
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? prefix;
  final String text;

  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(color: color);
    final prefix = this.prefix;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSpacing.lg, color: color),
          const SizedBox(width: AppSpacing.xs),
          if (prefix != null) ...[
            Text(prefix, style: style?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
