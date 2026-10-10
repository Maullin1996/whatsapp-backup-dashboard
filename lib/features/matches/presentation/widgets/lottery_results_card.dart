import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/lottery_results.dart';

/// Resumen de las loterías que se jugaron el día elegido, con sus números
/// ganadores. Se puede plegar para dejar a la vista solo la lista de grupos.
/// Un número que algún Revisor acertó va en verde.
class LotteryResultsCard extends StatefulWidget {
  final List<LotteryResult> results;

  const LotteryResultsCard({super.key, required this.results});

  @override
  State<LotteryResultsCard> createState() => _LotteryResultsCardState();
}

class _LotteryResultsCardState extends State<LotteryResultsCard> {
  bool _expanded = true;

  static const _gap = AppSpacing.sm;

  /// Ancho de la tarjeta desde el que las loterías van en dos columnas.
  static const _twoColumnsFrom = 520.0;

  @override
  Widget build(BuildContext context) {
    final results = widget.results;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: AppRadius.cardAll,
            onTap: results.isEmpty
                ? null
                : () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.casino_rounded,
                    size: 22,
                    color: AppColors.accentTeal,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Resultados del día',
                      style: AppTypography.headerTitle(context),
                    ),
                  ),
                  if (results.isNotEmpty) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.accentTeal.withValues(alpha: 0.12),
                        borderRadius: AppRadius.pillAll,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        child: Text(
                          results.length == 1
                              ? '1 lotería'
                              : '${results.length} loterías',
                          style: AppTypography.badge.copyWith(
                            color: AppColors.accentTeal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(
                'Todavía no hay números ganadores para esta fecha',
                style: textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= _twoColumnsFrom
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - _gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: _gap,
                    runSpacing: _gap,
                    children: [
                      for (final result in results)
                        SizedBox(
                          width: width,
                          child: _LotteryTile(result: result),
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Una lotería: su nombre y sus números.
class _LotteryTile extends StatelessWidget {
  final LotteryResult result;

  const _LotteryTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.screenBackground.withValues(alpha: 0.5),
        borderRadius: AppRadius.tileAll,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              result.nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.end,
              children: [
                for (final numero in result.numeros)
                  _NumberChip(
                    numero: numero,
                    conGanadores: result.conGanadores.contains(numero),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NumberChip extends StatelessWidget {
  final String numero;
  final bool conGanadores;

  const _NumberChip({required this.numero, required this.conGanadores});

  @override
  Widget build(BuildContext context) {
    final color = conGanadores ? AppColors.success : Colors.black87;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: conGanadores ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: AppRadius.buttonAll,
        border: Border.all(color: conGanadores ? color : Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          numero,
          style: Theme.of(context).textTheme.titleSmall
              ?.merge(AppTypography.tabular)
              .copyWith(fontWeight: FontWeight.w800, color: color),
        ),
      ),
    );
  }
}
