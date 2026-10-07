import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';

/// Los ganadores de un grupo en un día: lo que muestra una tarjeta de la
/// lista de Coincidencias y, al abrirla, su detalle.
class GroupMatches {
  final String chatJid;
  final String groupName;

  /// Una entrada por número del Revisor que coincidió con un ganador, de
  /// todas las jornadas del día (la jornada ya no se separa en pantalla).
  final List<MatchEntry> matches;

  const GroupMatches({
    required this.chatJid,
    required this.groupName,
    required this.matches,
  });

  /// Cantidad de ganadores (coincidencias) del grupo.
  int get winners => matches.length;
}

/// Agrupa las coincidencias de [day] por grupo (`chatJid`): primero los
/// grupos con más ganadores y, a igual cantidad, por nombre. Solo aparecen
/// los grupos con al menos un ganador. Dentro de un grupo se conserva el
/// orden en que llegan las coincidencias.
List<GroupMatches> groupMatchesOf(DayMatches day) {
  final byGroup = <String, List<MatchEntry>>{};
  for (final jornada in day.jornadas) {
    for (final match in jornada.matches) {
      byGroup.putIfAbsent(match.chatJid, () => []).add(match);
    }
  }
  return [
    for (final entry in byGroup.entries)
      GroupMatches(
        chatJid: entry.key,
        groupName: entry.value.first.groupName,
        matches: entry.value,
      ),
  ]..sort((a, b) {
    final byCount = b.winners.compareTo(a.winners);
    if (byCount != 0) return byCount;
    final byName = a.groupName.toLowerCase().compareTo(
      b.groupName.toLowerCase(),
    );
    return byName != 0 ? byName : a.chatJid.compareTo(b.chatJid);
  });
}
