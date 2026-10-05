import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/imagenes_faltantes.dart';

RoleSummary _registrado(int imagenes, {int total = 90000}) => RoleSummary(
  registrado: true,
  cantidadImagenes: imagenes,
  cantidadTickets: imagenes * 2,
  totalSuma: total,
);

JornadaSummary _summary({
  RoleSummary? revisor,
  RoleSummary? sumador,
  int contador = 10,
  String? shift,
  String fecha = '2026-09-28',
}) => JornadaSummary(
  chatJid: 'g1@g.us',
  groupName: 'Grupo',
  fechaJornada: fecha,
  shift: shift ?? shiftNames[Shift.morning]!,
  revisor: revisor ?? _registrado(10),
  sumador: sumador ?? _registrado(10),
  imagenesEnJornada: contador,
);

// La mañana del 28 termina a las 10:52 en Bogotá (15:52 UTC).
final _despues = DateTime.utc(2026, 9, 28, 16);
final _antes = DateTime.utc(2026, 9, 28, 15, 51, 59);

void main() {
  group('shiftImageCountDocId', () {
    test('formato exacto: chatJid_fecha_shiftKey', () {
      expect(
        shiftImageCountDocId('120363@g.us', '2026-09-28', Shift.afternoon1),
        '120363@g.us_2026-09-28_afternoon1',
      );
    });

    test('el shiftKey es el nombre del enum, sin traducir', () {
      for (final shift in shiftLastMinute.keys) {
        expect(
          shiftImageCountDocId('c', '2026-09-28', shift),
          'c_2026-09-28_${shift.name}',
        );
      }
    });

    test('null para outOfShift', () {
      expect(shiftImageCountDocId('c', '2026-09-28', Shift.outOfShift), isNull);
    });
  });

  group('imagenesFaltantes', () {
    test('jornada en curso: null aunque falten imágenes', () {
      final s = _summary(revisor: _registrado(3));

      expect(imagenesFaltantes(s, ReviewRole.revisor, _antes), isNull);
    });

    test('jornada terminada y el rol registró menos: la diferencia', () {
      final s = _summary(revisor: _registrado(7), sumador: _registrado(9));

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), 3);
      expect(imagenesFaltantes(s, ReviewRole.sumador, _despues), 1);
    });

    test('registró igual que el contador: 0', () {
      final s = _summary(revisor: _registrado(10));

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), 0);
    });

    test('registró MÁS que el contador: 0, nunca negativo', () {
      final s = _summary(revisor: _registrado(12), contador: 10);

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), 0);
    });

    test('contador 0 con registros (documento inexistente): 0', () {
      final s = _summary(contador: 0);

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), 0);
      expect(imagenesFaltantes(s, ReviewRole.sumador, _despues), 0);
    });

    test('rol sin registrar: null, aunque el contador no sea 0', () {
      final s = _summary(revisor: RoleSummary.sinRegistrar, contador: 8);

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), isNull);
      // El otro rol sí se evalúa.
      expect(imagenesFaltantes(s, ReviewRole.sumador, _despues), 0);
    });

    test('es por rol: no depende de lo que registró el otro', () {
      final s = _summary(
        revisor: _registrado(4),
        sumador: RoleSummary.sinRegistrar,
      );

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), 6);
    });

    test('etiqueta de jornada desconocida: null', () {
      final s = _summary(shift: 'Jornada Inventada (00:00 – 01:00)');

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), isNull);
    });

    test('"Fuera de las jornadas": null', () {
      final s = _summary(shift: shiftNames[Shift.outOfShift]!);

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), isNull);
    });

    test('un día pasado siempre está terminado', () {
      final s = _summary(fecha: '2026-09-01', revisor: _registrado(1));

      expect(imagenesFaltantes(s, ReviewRole.revisor, _antes), 9);
    });

    test('no toca el estado de dinero', () {
      final s = _summary(
        revisor: _registrado(1, total: 50000),
        sumador: _registrado(1, total: 50000),
      );

      expect(imagenesFaltantes(s, ReviewRole.revisor, _despues), 9);
      expect(s.estado, const JornadaEstado.cuadra());
    });
  });
}
