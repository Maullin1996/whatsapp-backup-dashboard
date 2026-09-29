import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/match_detail_dialog.dart';

/// Una jornada de Coincidencias: sus números ganadores y, si los hay, las
/// coincidencias encontradas. Nunca se combina con otra jornada del mismo día
/// (`image-review-domain`, reglas 4 y 5): esta tarjeta es la unidad completa.
class JornadaMatchesSection extends StatelessWidget {
  final JornadaMatches jornada;

  const JornadaMatchesSection({super.key, required this.jornada});

  @override
  Widget build(BuildContext context) {
    final hasWinners = jornada.winningNumbers.isNotEmpty;
    final hasMatches = jornada.matches.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shortShiftName(jornada.shift),
            style: AppTypography.headerTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          _WinningNumbersRow(numbers: jornada.winningNumbers),
          if (hasWinners && !hasMatches) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No hubo ganadores',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
          if (hasMatches) ...[
            const SizedBox(height: AppSpacing.sm),
            for (final match in jornada.matches) ...[
              _MatchTile(match: match),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

/// Los números ganadores de la jornada, tal cual (conservan ceros a la
/// izquierda), o el aviso de que todavía no hay ninguno.
class _WinningNumbersRow extends StatelessWidget {
  final List<String> numbers;

  const _WinningNumbersRow({required this.numbers});

  @override
  Widget build(BuildContext context) {
    if (numbers.isEmpty) {
      return Text(
        'Aún no hay números ganadores',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        const Text(
          'Números ganadores:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        for (final numero in numbers) _NumberChip(numero: numero),
      ],
    );
  }
}

/// Píldora con un número ganador (patrón de badge: fondo al 12 % de alpha,
/// texto del mismo color, radio pill). Cifras de ancho fijo para comparar a
/// simple vista.
class _NumberChip extends StatelessWidget {
  final String numero;

  const _NumberChip({required this.numero});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.accentTeal.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillAll,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Text(
          numero,
          style: AppTypography.badge
              .copyWith(color: AppColors.accentTeal)
              .merge(AppTypography.tabular),
        ),
      ),
    );
  }
}

/// Una coincidencia: número, quién la envió, a qué grupo pertenece y cuándo,
/// con acceso al detalle completo.
///
/// Móvil y escritorio distribuyen estos mismos datos distinto (ver
/// `_MatchTileMobile`/`_MatchTileDesktop`): a 360 px el `chatJid` completo no
/// entra en una fila junto al número, remitente, grupo y botón, así que en
/// escritorio se apila una fila con columnas y en móvil se apila verticalmente
/// con el chatJid en su propia línea, sin recortar.
class _MatchTile extends StatelessWidget {
  final MatchEntry match;

  const _MatchTile({required this.match});

  void _openDetail(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => MatchDetailDialog(match: match),
  );

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _MatchTileMobile(
        match: match,
        onVerMas: () => _openDetail(context),
      ),
      desktop: _MatchTileDesktop(
        match: match,
        onVerMas: () => _openDetail(context),
      ),
    );
  }
}

TextStyle _numeroStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .titleMedium!
    .copyWith(fontWeight: FontWeight.w700)
    .merge(AppTypography.tabular);

/// Móvil: apilado, con el chatJid completo en su propia línea (sin
/// `maxLines`/`overflow`, puede envolver a varias líneas si hace falta).
class _MatchTileMobile extends StatelessWidget {
  final MatchEntry match;
  final VoidCallback onVerMas;

  const _MatchTileMobile({required this.match, required this.onVerMas});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('match_tile_mobile'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: AppRadius.tileAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(match.numero, style: _numeroStyle(context)),
              const Spacer(),
              Text(match.localTime, style: AppTypography.timestamp(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(match.senderName, style: AppTypography.senderName(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(match.groupName),
          const SizedBox(height: AppSpacing.xs),
          Text(match.chatJid, style: AppTypography.timestamp(context)),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onVerMas,
              child: const Text('Ver más'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Escritorio: una fila con columnas. Solo el nombre del grupo puede
/// acortarse con ellipsis; el chatJid y el número nunca se recortan.
class _MatchTileDesktop extends StatelessWidget {
  final MatchEntry match;
  final VoidCallback onVerMas;

  const _MatchTileDesktop({required this.match, required this.onVerMas});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('match_tile_desktop'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.screenBackground,
        borderRadius: AppRadius.tileAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(match.numero, style: _numeroStyle(context)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 2,
            child: Text(
              match.senderName,
              style: AppTypography.senderName(context),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 3,
            // Columna, no fila: si "grupo (chatJid)" no entra en una sola
            // línea, el chatJid pasa a la línea siguiente en vez de
            // desbordar horizontalmente (nunca se recorta con ellipsis).
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  match.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '(${match.chatJid})',
                  style: AppTypography.timestamp(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(match.localTime, style: AppTypography.timestamp(context)),
          const SizedBox(width: AppSpacing.sm),
          TextButton(onPressed: onVerMas, child: const Text('Ver más')),
        ],
      ),
    );
  }
}
