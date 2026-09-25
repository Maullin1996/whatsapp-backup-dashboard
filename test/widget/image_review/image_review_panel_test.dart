import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/image_review_panel.dart';

const _target = ImageReviewTarget(
  messageId: 'm1',
  chatJid: 'chat@g.us',
  shift: 'Jornada Mañana',
);

const _email = 'revisor@test.com';

Widget _app({required Widget child}) => ProviderScope(
  overrides: [reviewerEmailProvider.overrideWithValue(_email)],
  child: MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: 420, height: 2300, child: child),
      ),
    ),
  ),
);

Future<ProviderContainer> _pumpPanel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(child: const ImageReviewPanel(target: _target)));
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(ImageReviewPanel)));
}

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key(key)).controller!.text;

Future<void> _fillValid(
  WidgetTester tester, {
  int id = 0,
  String codigo = 'A1',
  String numero = '0123',
  String total = '9000',
}) async {
  await tester.enterText(_key('codigo-$id'), codigo);
  await tester.enterText(_key('numero-$id'), numero);
  await tester.tap(_key('agregar-numero-$id'));
  await tester.pump();
  await tester.enterText(_key('total-$id'), total);
  await tester.pump();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ElevatedButton, label));
  await tester.pumpAndSettle();
}

Future<ImageReviewRecord?> _savedRecord(ProviderContainer container) async {
  final result = await container
      .read(imageReviewRepositoryProvider)
      .getByMessageId('m1');
  return result.fold((_) => fail('no se esperaba Left'), (r) => r);
}

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

void main() {
  group('comprobantes', () {
    testWidgets('empieza con 1 comprobante vacío y no se puede quitar', (
      tester,
    ) async {
      await _pumpPanel(tester);

      expect(find.text('Comprobante 1'), findsOneWidget);
      final remove = tester.widget<IconButton>(_key('quitar-0'));
      expect(remove.onPressed, isNull);
      expect(remove.tooltip, 'Debe haber al menos un comprobante');
    });

    testWidgets('agregar y quitar comprobantes', (tester) async {
      await _pumpPanel(tester);

      await tester.tap(find.text('Agregar comprobante'));
      await tester.pump();
      expect(find.text('Comprobante 2'), findsOneWidget);
      expect(tester.widget<IconButton>(_key('quitar-0')).onPressed, isNotNull);

      await tester.tap(_key('quitar-1')); // vacío: sin confirmación
      await tester.pumpAndSettle();
      expect(find.text('Comprobante 2'), findsNothing);
      expect(tester.widget<IconButton>(_key('quitar-0')).onPressed, isNull);
    });

    testWidgets('quitar un comprobante con datos pide confirmación', (
      tester,
    ) async {
      await _pumpPanel(tester);
      await tester.tap(find.text('Agregar comprobante'));
      await tester.pump();
      await tester.enterText(_key('codigo-1'), 'B2');
      await tester.pump(); // enterText no dibuja un frame por sí solo

      await tester.tap(_key('quitar-1'));
      await tester.pumpAndSettle();
      expect(find.text('¿Quitar comprobante?'), findsOneWidget);

      await tester.tap(_inDialog('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Comprobante 2'), findsOneWidget);

      await tester.tap(_key('quitar-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Comprobante 2'), findsNothing);
    });
  });

  group('números', () {
    testWidgets('se agregan con "+" y con Enter, y se quitan con la x del chip', (
      tester,
    ) async {
      await _pumpPanel(tester);

      await tester.enterText(_key('numero-0'), '5311');
      await tester.tap(_key('agregar-numero-0'));
      await tester.pump();
      expect(find.widgetWithText(InputChip, '5311'), findsOneWidget);
      expect(_text(tester, 'numero-0'), isEmpty);

      await tester.enterText(_key('numero-0'), '  1111 ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.widgetWithText(InputChip, '1111'), findsOneWidget);

      await tester.tap(find.byTooltip('Quitar número').first);
      await tester.pump();
      expect(find.widgetWithText(InputChip, '5311'), findsNothing);
      expect(find.widgetWithText(InputChip, '1111'), findsOneWidget);
    });

    testWidgets('un número vacío no se agrega', (tester) async {
      await _pumpPanel(tester);

      await tester.enterText(_key('numero-0'), '   ');
      await tester.tap(_key('agregar-numero-0'));
      await tester.pump();
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('conservan los ceros a la izquierda', (tester) async {
      final container = await _pumpPanel(tester);

      await _fillValid(tester, numero: '0123');
      expect(find.widgetWithText(InputChip, '0123'), findsOneWidget);

      await _tapButton(tester, 'Guardar');
      final record = await _savedRecord(container);
      expect(record!.form.comprobantes.single.numeros, ['0123']);
    });

    testWidgets('un número tipeado sin Enter/"+" se agrega al guardar', (
      tester,
    ) async {
      final container = await _pumpPanel(tester);

      await tester.enterText(_key('codigo-0'), 'A1');
      await tester.enterText(_key('numero-0'), '0042');
      await tester.enterText(_key('total-0'), '500');
      await _tapButton(tester, 'Guardar');

      final record = await _savedRecord(container);
      expect(record!.form.comprobantes.single.numeros, ['0042']);
    });
  });

  group('total', () {
    testWidgets('solo acepta dígitos', (tester) async {
      await _pumpPanel(tester);

      await tester.enterText(_key('total-0'), 'a1b2-3.4');
      await tester.pump();
      expect(_text(tester, 'total-0'), '1234');
    });
  });

  group('guardar', () {
    testWidgets('inválido: muestra errores inline y el mensaje, y no guarda', (
      tester,
    ) async {
      final container = await _pumpPanel(tester);
      expect(find.text('Obligatorio'), findsNothing);

      await _tapButton(tester, 'Guardar');

      expect(find.text('Comprobante 1: ingresa el código'), findsOneWidget);
      expect(find.text('Obligatorio'), findsNWidgets(2)); // código y total
      expect(find.text('Agrega al menos un número'), findsOneWidget);
      expect(await _savedRecord(container), isNull);
      expect(find.text('Editar'), findsNothing);
    });

    testWidgets('total 0 muestra "Debe ser mayor que 0"', (tester) async {
      await _pumpPanel(tester);

      await _fillValid(tester, total: '0');
      await _tapButton(tester, 'Guardar');

      expect(find.text('Debe ser mayor que 0'), findsOneWidget);
      expect(
        find.text('Comprobante 1: el total debe ser mayor que 0'),
        findsOneWidget,
      );
    });

    testWidgets('válido: guarda con los datos del target y del usuario', (
      tester,
    ) async {
      final container = await _pumpPanel(tester);

      await _fillValid(tester, codigo: '  A1 ', total: '9000');
      await tester.enterText(_key('anotaciones'), '  ilegible ');
      await _tapButton(tester, 'Guardar');

      final record = await _savedRecord(container);
      expect(record, isNotNull);
      expect(record!.messageId, 'm1');
      expect(record.chatJid, 'chat@g.us');
      expect(record.shift, 'Jornada Mañana');
      expect(record.registradoPor, _email);
      expect(record.editado, isFalse);
      expect(record.form.comprobantes.single.codigo, 'A1');
      expect(record.form.comprobantes.single.total, 9000);
      expect(record.form.anotaciones, 'ilegible');
      expect(container.read(canAdvanceProvider('m1')), isTrue);
    });
  });

  group('modo lectura', () {
    testWidgets('muestra el registro con formato de pesos y "Editar"', (
      tester,
    ) async {
      await _pumpPanel(tester);

      await _fillValid(tester);
      await tester.enterText(_key('anotaciones'), 'nota');
      await _tapButton(tester, 'Guardar');

      expect(find.text('Código: A1'), findsOneWidget);
      expect(find.widgetWithText(Chip, '0123'), findsOneWidget);
      expect(find.text('Total: \$9.000'), findsOneWidget);
      expect(find.text('nota'), findsOneWidget);
      expect(find.text('Editado'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Editar'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Guardar'), findsNothing);
    });

    testWidgets('re-guardar marca editado = true y muestra el badge', (
      tester,
    ) async {
      final container = await _pumpPanel(tester);
      await _fillValid(tester);
      await _tapButton(tester, 'Guardar');

      await _tapButton(tester, 'Editar');
      // El borrador se copia del registro guardado.
      expect(_text(tester, 'codigo-0'), 'A1');
      expect(_text(tester, 'total-0'), '9000');
      expect(find.widgetWithText(InputChip, '0123'), findsOneWidget);

      await tester.enterText(_key('total-0'), '12000');
      await _tapButton(tester, 'Guardar');

      final record = await _savedRecord(container);
      expect(record!.editado, isTrue);
      expect(record.form.comprobantes.single.total, 12000);
      expect(find.text('Total: \$12.000'), findsOneWidget);
      expect(find.text('Editado'), findsOneWidget);
    });
  });

  group('descartar cambios', () {
    Future<void> saveAndEdit(WidgetTester tester) async {
      await _pumpPanel(tester);
      await _fillValid(tester);
      await _tapButton(tester, 'Guardar');
      await _tapButton(tester, 'Editar');
    }

    testWidgets('Cancelar sin cambios vuelve a lectura sin preguntar', (
      tester,
    ) async {
      await saveAndEdit(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Editar'), findsOneWidget);
    });

    testWidgets('Cancelar con cambios pide confirmación', (tester) async {
      await saveAndEdit(tester);
      await tester.enterText(_key('total-0'), '12000');

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Descartar cambios?'), findsOneWidget);

      // Seguir editando conserva el formulario y los cambios.
      await tester.tap(find.widgetWithText(TextButton, 'Seguir editando'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Guardar'), findsOneWidget);
      expect(_text(tester, 'total-0'), '12000');

      // Descartar vuelve a lectura con el registro original.
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Descartar'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Editar'), findsOneWidget);
      expect(find.text('Total: \$9.000'), findsOneWidget);
    });
  });

  testWidgets('el borrador se conserva al salir y volver a la imagen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewerEmailProvider.overrideWithValue(_email)],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, show, _) => show
                  ? const Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 420,
                        height: 2300,
                        child: ImageReviewPanel(target: _target),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(_key('codigo-0'), 'BORRADOR');
    await tester.enterText(_key('total-0'), '777');

    visible.value = false;
    await tester.pumpAndSettle();
    expect(find.byType(ImageReviewPanel), findsNothing);

    visible.value = true;
    await tester.pumpAndSettle();
    expect(_text(tester, 'codigo-0'), 'BORRADOR');
    expect(_text(tester, 'total-0'), '777');
  });
}
