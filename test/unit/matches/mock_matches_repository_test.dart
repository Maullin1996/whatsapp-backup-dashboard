import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/mock_matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';

void main() {
  const repo = MockMatchesRepository(latency: Duration.zero);

  Future<DayMatches> load(DateTime date) async =>
      (await repo.getMatches(date)).fold((_) => fail('Left'), (d) => d);

  Future<List<DayMatches>> days(int count, {DateTime? from}) async => [
    for (var d = 0; d < count; d++)
      await load((from ?? DateTime(2026, 1, 1)).add(Duration(days: d))),
  ];

  test(
    'la misma fecha da exactamente los mismos datos, una y otra vez',
    () async {
      final date = DateTime(2026, 9, 26);

      final first = await load(date);
      final second = await load(date);
      final third = await load(DateTime(2026, 9, 26));

      expect(second, first);
      expect(third, first);
    },
  );

  test('solo cuenta el día: la hora no cambia los datos', () async {
    expect(
      await load(DateTime(2026, 9, 26, 18, 45)),
      await load(DateTime(2026, 9, 26)),
    );
  });

  test('fechas distintas dan datos distintos', () async {
    final a = await load(DateTime(2026, 9, 26));
    final b = await load(DateTime(2026, 9, 25));

    expect(b, isNot(a));
  });

  test('devuelve la fecha pedida como yyyy-MM-dd', () async {
    final day = await load(DateTime(2026, 3, 5));

    expect(day.fechaJornada, '2026-03-05');
  });

  test(
    'las jornadas usan las etiquetas de shifts.dart, sin duplicarlas',
    () async {
      final valid = shiftNames.values.toSet();
      for (var d = 0; d < 60; d++) {
        final day = await load(DateTime(2026, 1, 1).add(Duration(days: d)));

        expect(day.jornadas.every((j) => valid.contains(j.shift)), isTrue);
      }
    },
  );

  group('ninguna jornada mezcla datos ni se acumula entre fechas (reglas '
      '4 y 5)', () {
    test('cada MatchEntry lleva la fechaJornada del día consultado, nunca '
        'otra', () async {
      for (final day in await days(30)) {
        for (final jornada in day.jornadas) {
          for (final entry in jornada.matches) {
            expect(entry.fechaJornada, day.fechaJornada);
          }
        }
      }
    });

    test('cada MatchEntry lleva la etiqueta de SU jornada, no la de otra '
        'del mismo día', () async {
      for (final day in await days(30)) {
        for (final jornada in day.jornadas) {
          for (final entry in jornada.matches) {
            expect(entry.shift, jornada.shift);
          }
        }
      }
    });

    test('no hay una jornada repetida ni un total combinado del día: una '
        'JornadaMatches por jornada', () async {
      for (final day in await days(30)) {
        final shifts = day.jornadas.map((j) => j.shift).toList();
        expect(shifts.toSet().length, shifts.length);
      }
    });

    test('un día no reutiliza los ganadores/coincidencias de otro día '
        'consecutivo', () async {
      final list = await days(30);
      for (var i = 1; i < list.length; i++) {
        expect(list[i], isNot(list[i - 1]));
      }
    });
  });

  group('variedad alcanzable (los cinco escenarios pedidos)', () {
    test('un ganador con una coincidencia', () async {
      final found = (await days(120)).any(
        (day) => day.jornadas.any(
          (j) => j.winningNumbers.length == 1 && j.matches.length == 1,
        ),
      );
      expect(found, isTrue, reason: 'nunca apareció en 120 días');
    });

    test('la misma cifra da coincidencias en dos grupos distintos', () async {
      final found = (await days(120)).any(
        (day) => day.jornadas.any((j) {
          final byGroup = j.matches.map((m) => m.chatJid).toSet();
          return j.matches.length >= 2 &&
              byGroup.length >= 2 &&
              j.matches.map((m) => m.numero).toSet().length == 1;
        }),
      );
      expect(found, isTrue, reason: 'nunca apareció en 120 días');
    });

    test('una jornada con ganadores pero sin coincidencias', () async {
      final found = (await days(120)).any(
        (day) => day.jornadas.any(
          (j) => j.winningNumbers.isNotEmpty && j.matches.isEmpty,
        ),
      );
      expect(found, isTrue, reason: 'nunca apareció en 120 días');
    });

    test('un día sin ganadores: todas las jornadas con lista vacía', () async {
      final found = (await days(
        120,
      )).any((day) => day.jornadas.every((j) => j.winningNumbers.isEmpty));
      expect(found, isTrue, reason: 'nunca apareció en 120 días');
      // Ese día tampoco tiene coincidencias, y `tieneGanador` lo refleja.
      final day = (await days(
        120,
      )).firstWhere((d) => d.jornadas.every((j) => j.winningNumbers.isEmpty));
      expect(day.jornadas.every((j) => j.matches.isEmpty), isTrue);
      expect(day.tieneGanador, isFalse);
    });

    test('ceros a la izquierda: "0123" coincide, "123" (registrado aparte) '
        'no', () async {
      bool hasCase(DayMatches day) => day.jornadas.any((j) {
        if (!j.winningNumbers.contains('0123')) return false;
        final matched = j.matches.map((m) => m.numero).toSet();
        return matched.contains('0123') && !matched.contains('123');
      });

      final found = (await days(120)).any(hasCase);
      expect(found, isTrue, reason: 'nunca apareció en 120 días');
    });
  });

  test('los datos son claramente falsos (demo)', () async {
    for (final day in await days(20)) {
      for (final jornada in day.jornadas) {
        for (final MatchEntry entry in jornada.matches) {
          expect(entry.chatJid, contains('demo'));
          expect(entry.storagePath, startsWith('demo/'));
        }
      }
    }
  });

  test('cada JornadaMatches viene de findMatches: toda coincidencia listada '
      'realmente tiene su número entre los ganadores de esa jornada', () async {
    for (final day in await days(30)) {
      for (final JornadaMatches jornada in day.jornadas) {
        final winners = jornada.winningNumbers.map((n) => n.trim()).toSet();
        for (final entry in jornada.matches) {
          expect(winners.contains(entry.numero.trim()), isTrue);
        }
      }
    }
  });
}
