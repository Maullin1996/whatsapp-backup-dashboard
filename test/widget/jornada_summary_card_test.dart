import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/jornada_summary_card.dart';

RoleSummary _role(int imagenes, {int total = 90000}) => RoleSummary(
  registrado: true,
  cantidadImagenes: imagenes,
  cantidadTickets: imagenes * 2,
  totalSuma: total,
);

JornadaSummary _summary({
  RoleSummary? revisor,
  RoleSummary? sumador,
  int contador = 10,
}) => JornadaSummary(
  chatJid: 'g1@g.us',
  groupName: 'Grupo',
  fechaJornada: '2026-09-28',
  shift: shiftNames[Shift.morning]!,
  revisor: revisor ?? _role(10),
  sumador: sumador ?? _role(10),
  imagenesEnJornada: contador,
);

// La mañana del 28 termina a las 10:52 en Bogotá (15:52 UTC).
final _terminada = DateTime.utc(2026, 9, 28, 16);
final _enCurso = DateTime.utc(2026, 9, 28, 15, 51, 59);

Future<void> _pump(WidgetTester tester, JornadaSummary summary, DateTime now) =>
    tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: JornadaSummaryCard(summary: summary, now: now),
          ),
        ),
      ),
    );

final _aviso = RegExp(r'por registrar$');

void main() {
  group('aviso de imágenes sin registrar', () {
    testWidgets('jornada terminada, rol registrado y faltantes > 0: aparece '
        'bajo el rol, en plural', (tester) async {
      await _pump(
        tester,
        _summary(revisor: _role(7), sumador: _role(10)),
        _terminada,
      );

      expect(find.text('Faltan 3 imágenes por registrar'), findsOneWidget);
      expect(find.textContaining(_aviso), findsOneWidget);
      // Va debajo de la fila del Revisor y encima de la del Sumador.
      final revisor = tester.getTopLeft(find.textContaining('Revisor:')).dy;
      final aviso = tester
          .getTopLeft(find.text('Faltan 3 imágenes por registrar'))
          .dy;
      final sumador = tester.getTopLeft(find.textContaining('Sumador:')).dy;
      expect(aviso, greaterThan(revisor));
      expect(aviso, lessThan(sumador));
    });

    testWidgets('singular: "Falta 1 imagen por registrar"', (tester) async {
      await _pump(tester, _summary(sumador: _role(9)), _terminada);

      expect(find.text('Falta 1 imagen por registrar'), findsOneWidget);
      expect(find.text('Faltan 1 imágenes por registrar'), findsNothing);
    });

    testWidgets('los dos roles pueden tener su propio aviso', (tester) async {
      await _pump(
        tester,
        _summary(revisor: _role(8), sumador: _role(9)),
        _terminada,
      );

      expect(find.text('Faltan 2 imágenes por registrar'), findsOneWidget);
      expect(find.text('Falta 1 imagen por registrar'), findsOneWidget);
    });

    testWidgets('jornada en curso: sin aviso', (tester) async {
      await _pump(tester, _summary(revisor: _role(3)), _enCurso);

      expect(find.textContaining(_aviso), findsNothing);
    });

    testWidgets('a las 10:52:00 en punto ya aparece', (tester) async {
      await _pump(
        tester,
        _summary(revisor: _role(3)),
        DateTime.utc(2026, 9, 28, 15, 52),
      );

      expect(find.text('Faltan 7 imágenes por registrar'), findsOneWidget);
    });

    testWidgets('rol sin registrar: sin aviso (lo cubre el badge)', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(revisor: RoleSummary.sinRegistrar, contador: 8),
        _terminada,
      );

      expect(find.textContaining(_aviso), findsNothing);
      expect(find.text('Falta Revisor'), findsOneWidget);
    });

    testWidgets('registró igual o más que el contador: sin aviso', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(revisor: _role(10), sumador: _role(12)),
        _terminada,
      );

      expect(find.textContaining(_aviso), findsNothing);
    });

    testWidgets('no muestra el total del contador, solo la diferencia', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(revisor: _role(7), contador: 10),
        _terminada,
      );

      // El contador es 10 y el Revisor registró 7: el aviso dice solo "3".
      expect(find.text('Faltan 3 imágenes por registrar'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^Faltan? .*10.* por registrar$')),
        findsNothing,
      );
    });

    testWidgets('tono neutro: ni el texto ni el icono van en rojo', (
      tester,
    ) async {
      await _pump(tester, _summary(revisor: _role(7)), _terminada);

      final text = tester.widget<Text>(
        find.text('Faltan 3 imágenes por registrar'),
      );
      final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline_rounded));

      expect(text.style?.color, Colors.grey.shade600);
      expect(icon.color, Colors.grey.shade600);
      expect(text.style?.color, isNot(Colors.red));
    });

    testWidgets('el badge de dinero no cambia con ni sin aviso', (
      tester,
    ) async {
      // Mismo dinero (cuadra); solo cambia si hay imágenes faltantes.
      await _pump(tester, _summary(), _terminada);
      expect(find.textContaining(_aviso), findsNothing);
      expect(find.text('Cuadra'), findsOneWidget);

      await _pump(
        tester,
        _summary(revisor: _role(4), sumador: _role(4)),
        _terminada,
      );
      expect(find.textContaining(_aviso), findsNWidgets(2));
      expect(find.text('Cuadra'), findsOneWidget);
      expect(find.textContaining('Descuadre'), findsNothing);
    });

    testWidgets('con un descuadre de dinero, el aviso sigue siendo aparte', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(
          revisor: _role(10, total: 90000),
          sumador: _role(9, total: 81000),
        ),
        _terminada,
      );

      expect(find.text('Descuadre de \$9.000'), findsOneWidget);
      expect(find.text('Falta 1 imagen por registrar'), findsOneWidget);
    });

    testWidgets('los textos del aviso no hablan de fraude ni de descuadre', (
      tester,
    ) async {
      await _pump(
        tester,
        _summary(revisor: _role(4), sumador: _role(9)),
        _terminada,
      );

      final avisos = tester
          .widgetList<Text>(find.textContaining(_aviso))
          .map((t) => t.data!.toLowerCase())
          .toList();

      expect(avisos, hasLength(2));
      for (final text in avisos) {
        expect(text, isNot(contains('fraude')));
        expect(text, isNot(contains('descuadre')));
      }
    });

    testWidgets('renderiza sin desbordes a 320 px con los dos avisos', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        _summary(revisor: _role(2), sumador: _role(3), contador: 250),
        _terminada,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Faltan 248 imágenes por registrar'), findsOneWidget);
    });
  });
}
