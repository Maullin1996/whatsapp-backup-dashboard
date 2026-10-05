import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/summary_overview.dart';

RoleSummary _role(int imagenes, int total) => RoleSummary(
  registrado: true,
  cantidadImagenes: imagenes,
  cantidadTickets: imagenes,
  totalSuma: total,
);

JornadaSummary _js(
  String jid, {
  required RoleSummary revisor,
  required RoleSummary sumador,
  int contador = 0,
}) => JornadaSummary(
  chatJid: jid,
  groupName: 'Grupo $jid',
  fechaJornada: '2026-09-28',
  shift: shiftNames[Shift.morning]!,
  revisor: revisor,
  sumador: sumador,
  imagenesEnJornada: contador,
);

// La mañana del 28 ya terminó (10:52 Bogotá = 15:52 UTC).
final _now = DateTime.utc(2026, 9, 28, 16);

void main() {
  final cuadra = _js('a', revisor: _role(5, 1000), sumador: _role(5, 1000));
  final cuadraConFaltantes = _js(
    'b',
    revisor: _role(5, 1000),
    sumador: _role(3, 1000),
    contador: 6,
  );
  final descuadre1 = _js('c', revisor: _role(5, 9000), sumador: _role(5, 1000));
  final descuadre2 = _js('d', revisor: _role(5, 1000), sumador: _role(5, 3000));
  final pendiente = _js(
    'e',
    revisor: _role(5, 1000),
    sumador: RoleSummary.sinRegistrar,
  );
  final all = [cuadra, cuadraConFaltantes, descuadre1, descuadre2, pendiente];

  group('SummaryOverview.of', () {
    test('cuenta estados, diferencias, grupos e imágenes', () {
      final o = SummaryOverview.of(all, _now);

      expect(o.jornadas, 5);
      expect(o.grupos, 5);
      expect(o.cuadran, 2);
      expect(o.descuadres, 2);
      expect(o.pendientes, 1);
      expect(o.totalDiferencias, 8000 + 2000);
      // b: Revisor 1 (6-5) + Sumador 3 (6-3).
      expect(o.jornadasConImagenes, 1);
      expect(o.imagenesSinRegistrar, 4);
    });

    test('lista vacía: todo en cero', () {
      final o = SummaryOverview.of(const [], _now);
      expect(o.jornadas, 0);
      expect(o.grupos, 0);
      expect(o.countOf(SummaryFilter.todas), 0);
    });

    test('jornada en curso: sus imágenes sin registrar no cuentan', () {
      final o = SummaryOverview.of([
        cuadraConFaltantes,
      ], DateTime.utc(2026, 9, 28, 15));
      expect(o.imagenesSinRegistrar, 0);
      expect(o.jornadasConImagenes, 0);
    });
  });

  test('matchesSummaryFilter separa cada estado', () {
    List<String> ids(SummaryFilter f) => [
      for (final s in all)
        if (matchesSummaryFilter(s, f, _now)) s.chatJid,
    ];

    expect(ids(SummaryFilter.todas), ['a', 'b', 'c', 'd', 'e']);
    expect(ids(SummaryFilter.descuadre), ['c', 'd']);
    expect(ids(SummaryFilter.pendiente), ['e']);
    expect(ids(SummaryFilter.cuadra), ['a', 'b']);
    expect(ids(SummaryFilter.imagenes), ['b']);
  });

  test('groupsBySeverity: descuadre, pendiente, imágenes, en orden; a igual '
      'gravedad conserva el orden de llegada', () {
    final groups = groupsBySeverity(all, _now);
    expect(groups.map((g) => g.first.chatJid), ['c', 'd', 'e', 'b', 'a']);
  });

  test('groupsBySeverity: un grupo toma la gravedad de su peor jornada', () {
    final g1Bien = _js('g1', revisor: _role(1, 1), sumador: _role(1, 1));
    final g2Bien = _js('g2', revisor: _role(1, 1), sumador: _role(1, 1));
    final g2Mal = _js('g2', revisor: _role(1, 2), sumador: _role(1, 1));

    final groups = groupsBySeverity([g1Bien, g2Bien, g2Mal], _now);
    expect(groups.map((g) => g.first.chatJid), ['g2', 'g1']);
    // Dentro del grupo, el orden de llegada.
    expect(groups.first, [g2Bien, g2Mal]);
  });
}
