import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/lottery_results.dart';

MatchEntry _m(String numero, String loteria, List<String> winning) =>
    MatchEntry(
      numero: numero,
      loteria: loteria,
      messageId: 'm$numero',
      chatJid: 'g@g.us',
      groupName: 'Grupo',
      senderName: 'Ana',
      localTime: '08:00',
      storagePath: 'x.jpg',
      shift: 'Jornada Mañana',
      fechaJornada: '2026-10-09',
      winningNumbers: winning,
    );

DayMatches _day(
  List<WinningEntry> winners, [
  List<MatchEntry> matches = const [],
]) => DayMatches(
  fechaJornada: '2026-10-09',
  jornadas: [
    JornadaMatches(
      shift: 'Jornada Mañana',
      winningNumbers: winners,
      matches: matches,
    ),
    JornadaMatches(
      shift: 'Jornada Tarde 1',
      winningNumbers: winners,
      matches: const [],
    ),
  ],
);

void main() {
  test('sin ganadores del día no hay resultados', () {
    expect(lotteryResultsOf(_day(const [])), isEmpty);
    expect(
      lotteryResultsOf(const DayMatches(fechaJornada: 'x', jornadas: [])),
      isEmpty,
    );
  });

  test('agrupa los números por lotería, ordenadas por nombre', () {
    final results = lotteryResultsOf(
      _day(const [
        WinningEntry(loteria: 'saman_dia', numero: '871'),
        WinningEntry(loteria: 'cafeterito_tarde', numero: '9014'),
        WinningEntry(loteria: 'saman_dia', numero: '4871'),
      ]),
    );

    expect(results.map((r) => r.nombre), ['Cafeterito tarde', 'Saman día']);
    expect(results.last.numeros, ['4871', '871']);
  });

  test('conserva los ceros a la izquierda y no repite números', () {
    final results = lotteryResultsOf(
      _day(const [
        WinningEntry(loteria: 'medellin', numero: '0414'),
        WinningEntry(loteria: 'medellin', numero: ' 0414 '),
      ]),
    );

    expect(results.single.numeros, ['0414']);
  });

  test('una entrada sin lotería se muestra como sin identificar', () {
    final results = lotteryResultsOf(
      _day(const [WinningEntry(loteria: '', numero: '123')]),
    );

    expect(results.single.nombre, 'Lotería sin identificar');
  });

  test('marca los números que algún registro acertó', () {
    final results = lotteryResultsOf(
      _day(
        const [
          WinningEntry(loteria: 'saman_dia', numero: '4871'),
          WinningEntry(loteria: 'saman_dia', numero: '0123'),
          WinningEntry(loteria: 'medellin', numero: '4871'),
        ],
        [
          _m('871', 'saman_dia', ['4871']),
        ],
      ),
    );

    final saman = results.firstWhere((r) => r.loteria == 'saman_dia');
    final medellin = results.firstWhere((r) => r.loteria == 'medellin');
    expect(saman.conGanadores, {'4871'});
    expect(medellin.conGanadores, isEmpty);
  });
}
