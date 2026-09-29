import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';

RoleSummary _registrado(int total) => RoleSummary(
  registrado: true,
  cantidadImagenes: 3,
  cantidadTickets: 8,
  totalSuma: total,
);

JornadaSummary _summary(RoleSummary revisor, RoleSummary sumador) =>
    JornadaSummary(
      chatJid: 'c1',
      groupName: 'Grupo',
      fechaJornada: '2026-09-26',
      shift: 'Jornada Mañana (06:00 – 10:54)',
      revisor: revisor,
      sumador: sumador,
      imagenesEnJornada: 0,
    );

void main() {
  group('JornadaSummary.estado', () {
    test('ambos registraron y las sumas coinciden: cuadra', () {
      expect(
        _summary(_registrado(135000), _registrado(135000)).estado,
        const JornadaEstado.cuadra(),
      );
    });

    test('ambos registraron y el Revisor suma más: descuadre con la '
        'diferencia', () {
      expect(
        _summary(_registrado(135000), _registrado(126000)).estado,
        const JornadaEstado.descuadre(diferencia: 9000),
      );
    });

    test('ambos registraron y el Sumador suma más: la diferencia es el valor '
        'absoluto', () {
      expect(
        _summary(_registrado(126000), _registrado(135000)).estado,
        const JornadaEstado.descuadre(diferencia: 9000),
      );
    });

    test('falta el Sumador: pendiente, dice cuál', () {
      expect(
        _summary(_registrado(135000), RoleSummary.sinRegistrar).estado,
        const JornadaEstado.pendiente(faltan: {ReviewRole.sumador}),
      );
    });

    test('falta el Revisor: pendiente, dice cuál', () {
      expect(
        _summary(RoleSummary.sinRegistrar, _registrado(135000)).estado,
        const JornadaEstado.pendiente(faltan: {ReviewRole.revisor}),
      );
    });

    test('faltan los dos: pendiente con ambos', () {
      expect(
        _summary(RoleSummary.sinRegistrar, RoleSummary.sinRegistrar).estado,
        const JornadaEstado.pendiente(
          faltan: {ReviewRole.revisor, ReviewRole.sumador},
        ),
      );
    });

    test('pendiente gana sobre las sumas: con uno sin registrar no hay '
        'descuadre aunque las sumas difieran', () {
      final estado = _summary(
        _registrado(135000),
        RoleSummary.sinRegistrar,
      ).estado;
      expect(estado, isA<JornadaPendiente>());
    });

    test('una jornada registrada con total 0 en ambos también cuadra', () {
      expect(
        _summary(_registrado(0), _registrado(0)).estado,
        const JornadaEstado.cuadra(),
      );
    });
  });

  test('RoleSummary.sinRegistrar va en ceros y sin registrar', () {
    expect(RoleSummary.sinRegistrar.registrado, isFalse);
    expect(RoleSummary.sinRegistrar.cantidadImagenes, 0);
    expect(RoleSummary.sinRegistrar.cantidadTickets, 0);
    expect(RoleSummary.sinRegistrar.totalSuma, 0);
  });
}
