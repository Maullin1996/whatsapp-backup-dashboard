import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/mock_summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';

void main() {
  const repo = MockSummaryRepository(latency: Duration.zero);

  Future<List<JornadaSummary>> load(DateTime date) async =>
      (await repo.getJornadaSummaries(
        date,
      )).fold((_) => fail('Left'), (list) => list);

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

  test('devuelve la fecha pedida como yyyy-MM-dd en cada jornada', () async {
    final list = await load(DateTime(2026, 3, 5));

    expect(list, isNotEmpty);
    expect(list.every((j) => j.fechaJornada == '2026-03-05'), isTrue);
  });

  test(
    'las jornadas son textos de shifts.dart y no se repiten por grupo',
    () async {
      final valid = shiftNames.values.toSet();
      for (var d = 1; d <= 60; d++) {
        final list = await load(DateTime(2026, 1, d));

        expect(list.every((j) => valid.contains(j.shift)), isTrue);
        final keys = list.map((j) => '${j.chatJid}|${j.shift}');
        expect(keys.toSet().length, keys.length, reason: 'día $d');
      }
    },
  );

  test('cada fecha tiene 2-3 grupos y los 4 casos: cuadra, descuadre, '
      'Sumador sin registrar y ambos sin registrar', () async {
    for (var d = 0; d < 90; d++) {
      final date = DateTime(2026, 1, 1).add(Duration(days: d));
      final list = await load(date);

      final groups = list.map((j) => j.chatJid).toSet();
      expect(groups.length, inInclusiveRange(2, 3), reason: '$date');

      bool any(bool Function(JornadaSummary) test) => list.any(test);
      expect(
        any((j) => j.estado is JornadaCuadra),
        isTrue,
        reason: 'cuadra $date',
      );
      expect(
        any((j) => j.estado is JornadaDescuadre),
        isTrue,
        reason: 'descuadre $date',
      );
      expect(
        any((j) => j.revisor.registrado && !j.sumador.registrado),
        isTrue,
        reason: 'falta Sumador $date',
      );
      expect(
        any((j) => !j.revisor.registrado && !j.sumador.registrado),
        isTrue,
        reason: 'ambos sin registrar $date',
      );
    }
  });

  test('los datos son coherentes: sin registrar va en ceros y el descuadre '
      'es distinto de cero', () async {
    for (var d = 0; d < 60; d++) {
      final list = await load(DateTime(2026, 5, 1).add(Duration(days: d)));

      for (final j in list) {
        for (final role in [j.revisor, j.sumador]) {
          if (role.registrado) {
            expect(role.cantidadTickets, greaterThan(0));
            expect(
              role.cantidadImagenes,
              inInclusiveRange(1, role.cantidadTickets),
            );
            expect(role.totalSuma, greaterThan(0));
          } else {
            expect(role.cantidadImagenes, 0);
            expect(role.cantidadTickets, 0);
            expect(role.totalSuma, 0);
          }
        }
        final estado = j.estado;
        if (estado is JornadaDescuadre) {
          expect(estado.diferencia, greaterThan(0));
        }
      }
    }
  });

  test(
    'las jornadas de un mismo grupo van juntas y en orden del día',
    () async {
      final list = await load(DateTime(2026, 9, 26));

      final seenGroups = <String>[];
      for (final j in list) {
        if (seenGroups.isEmpty || seenGroups.last != j.chatJid) {
          expect(seenGroups, isNot(contains(j.chatJid)));
          seenGroups.add(j.chatJid);
        }
      }
    },
  );
}
