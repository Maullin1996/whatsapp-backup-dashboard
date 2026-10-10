import 'package:whatsapp_monitor_viewer/core/lotteries/lotteries.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';

/// Lo que sacó una lotería en el día: sus números ganadores.
class LotteryResult {
  /// Identificador de la lotería (`lib/core/lotteries/lotteries.dart`); puede
  /// venir vacío o fuera de la lista (entrada sin slug).
  final String loteria;

  /// Sus números, tal cual (con ceros a la izquierda): primero los de más
  /// cifras, sin repetir.
  final List<String> numeros;

  /// Números de [numeros] con los que coincidió algún registro del Revisor.
  final Set<String> conGanadores;

  const LotteryResult({
    required this.loteria,
    required this.numeros,
    this.conGanadores = const {},
  });

  /// Nombre para mostrar; "Lotería sin identificar" si la entrada no trae
  /// lotería.
  String get nombre =>
      loteria.isEmpty ? 'Lotería sin identificar' : loteriaDisplayName(loteria);
}

/// Resumen del día por lotería, ordenado por nombre. Los números ganadores
/// son los mismos en todas las jornadas del día ([DayMatches]): se toman de la
/// primera que los traiga. Vacío si el día todavía no tiene ganadores.
///
/// [LotteryResult.conGanadores] marca los números que algún registro del
/// Revisor acertó (a partir de `MatchEntry.winningNumbers`).
List<LotteryResult> lotteryResultsOf(DayMatches day) {
  final winners = day.jornadas
      .map((j) => j.winningNumbers)
      .firstWhere((w) => w.isNotEmpty, orElse: () => const []);
  if (winners.isEmpty) return const [];

  final hit = <String, Set<String>>{};
  for (final jornada in day.jornadas) {
    for (final match in jornada.matches) {
      final loteria = match.loteria;
      if (loteria == null) continue;
      hit.putIfAbsent(loteria, () => {}).addAll(match.winningNumbers);
    }
  }

  final byLoteria = <String, Set<String>>{};
  for (final w in winners) {
    final numero = w.numero.trim();
    if (numero.isEmpty) continue;
    byLoteria.putIfAbsent(w.loteria, () => {}).add(numero);
  }

  return [
    for (final entry in byLoteria.entries)
      LotteryResult(
        loteria: entry.key,
        numeros: entry.value.toList()
          ..sort((a, b) {
            final byLength = b.length.compareTo(a.length);
            return byLength != 0 ? byLength : a.compareTo(b);
          }),
        conGanadores: entry.value.intersection(hit[entry.key] ?? const {}),
      ),
  ]..sort((a, b) => a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase()));
}
