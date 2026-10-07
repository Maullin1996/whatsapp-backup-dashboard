import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/group_matches.dart';

MatchEntry _m(String id, String jid, String group) => MatchEntry(
  numero: '1234',
  loteria: 'medellin',
  messageId: id,
  chatJid: jid,
  groupName: group,
  senderName: 'Ana',
  localTime: '08:00',
  storagePath: 'x/$id.jpg',
  shift: 'Jornada Mañana',
  fechaJornada: '2026-10-05',
);

JornadaMatches _j(List<MatchEntry> matches) => JornadaMatches(
  shift: 'Jornada Mañana',
  winningNumbers: const [],
  matches: matches,
);

void main() {
  test('agrupa por grupo juntando las jornadas del día', () {
    final groups = groupMatchesOf(
      DayMatches(
        fechaJornada: '2026-10-05',
        jornadas: [
          _j([_m('1', 'a@g.us', 'Alfa')]),
          _j([_m('2', 'a@g.us', 'Alfa'), _m('3', 'b@g.us', 'Beta')]),
        ],
      ),
    );

    expect(groups.map((g) => g.chatJid), ['a@g.us', 'b@g.us']);
    expect(groups.first.winners, 2);
    expect(groups.first.groupName, 'Alfa');
  });

  test('más ganadores primero; a igual cantidad, por nombre', () {
    final groups = groupMatchesOf(
      DayMatches(
        fechaJornada: '2026-10-05',
        jornadas: [
          _j([
            _m('1', 'c@g.us', 'Charlie'),
            _m('2', 'b@g.us', 'bravo'),
            _m('3', 'a@g.us', 'Alfa'),
            _m('4', 'a@g.us', 'Alfa'),
          ]),
        ],
      ),
    );

    expect(groups.map((g) => g.groupName), ['Alfa', 'bravo', 'Charlie']);
  });

  test('sin coincidencias no hay grupos', () {
    expect(
      groupMatchesOf(
        DayMatches(fechaJornada: '2026-10-05', jornadas: [_j(const [])]),
      ),
      isEmpty,
    );
  });

  test('knownGroups agrega los grupos sin ganadores con 0, al final', () {
    final groups = groupMatchesOf(
      DayMatches(
        fechaJornada: '2026-10-05',
        jornadas: [
          _j([_m('1', 'b@g.us', 'Beta')]),
        ],
      ),
      knownGroups: {'a@g.us': 'Alfa', 'b@g.us': 'Beta', 'c@g.us': 'Charlie'},
    );

    expect(groups.map((g) => (g.groupName, g.winners)), [
      ('Beta', 1),
      ('Alfa', 0),
      ('Charlie', 0),
    ]);
  });
}
