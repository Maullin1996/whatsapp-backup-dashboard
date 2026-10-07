import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/role_group_summary.dart';

RoleSummary _role(int imagenes, int tickets, int total) => RoleSummary(
  registrado: true,
  cantidadImagenes: imagenes,
  cantidadTickets: tickets,
  totalSuma: total,
);

JornadaSummary _js(
  Shift shift, {
  required RoleSummary revisor,
  required RoleSummary sumador,
  int imagenes = 0,
}) => JornadaSummary(
  chatJid: 'g1',
  groupName: 'Grupo',
  fechaJornada: '2026-09-28',
  shift: shiftNames[shift]!,
  revisor: revisor,
  sumador: sumador,
  imagenesEnJornada: imagenes,
);

void main() {
  // Pasadas las 10:51 de Bogotá: la mañana ya terminó, la tarde 1 no.
  final now = DateTime.utc(2026, 9, 28, 15, 52);
  final jornadas = [
    _js(
      Shift.morning,
      revisor: _role(7, 14, 90000),
      sumador: _role(10, 20, 80000),
      imagenes: 10,
    ),
    _js(
      Shift.afternoon1,
      revisor: _role(2, 3, 30000),
      sumador: RoleSummary.sinRegistrar,
    ),
  ];

  test('suma total, tickets e imágenes solo de las jornadas registradas', () {
    final revisor = RoleGroupSummary.of(ReviewRole.revisor, jornadas, now);
    expect(revisor.total, 120000);
    expect(revisor.tickets, 17);
    expect(revisor.imagenes, 9);
    expect(revisor.registradas, hasLength(2));
    expect(revisor.faltantes, isEmpty);
  });

  test('las jornadas sin registrar del rol quedan en faltantes', () {
    final sumador = RoleGroupSummary.of(ReviewRole.sumador, jornadas, now);
    expect(sumador.total, 80000);
    expect(sumador.registradas, hasLength(1));
    expect(
      sumador.faltantes.single.summary.shift,
      shiftNames[Shift.afternoon1],
    );
    expect(sumador.completo, isFalse);
  });

  test('imágenes sin registrar solo cuentan en jornadas terminadas', () {
    final revisor = RoleGroupSummary.of(ReviewRole.revisor, jornadas, now);
    expect(revisor.imagenesSinRegistrar, 3);
    expect(revisor.completo, isFalse);
  });

  test('sin nada registrado: total 0 y todas las jornadas faltan', () {
    final vacio = RoleGroupSummary.of(ReviewRole.sumador, [
      _js(
        Shift.morning,
        revisor: RoleSummary.sinRegistrar,
        sumador: RoleSummary.sinRegistrar,
      ),
    ], now);
    expect(vacio.total, 0);
    expect(vacio.registradas, isEmpty);
    expect(vacio.faltantes, hasLength(1));
  });
}
