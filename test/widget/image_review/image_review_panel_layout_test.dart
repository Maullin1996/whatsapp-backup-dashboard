import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/unavailable_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/image_review_panel.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_status_chip.dart';

const _target = ImageReviewTarget(
  messageId: 'm1',
  chatJid: 'chat@g.us',
  shift: 'Jornada Mañana',
  storagePath: 'img_m1.png',
  fechaJornada: '2026-01-15',
  localTime: '10:03',
  shiftImageIndex: 4,
);

Future<ProviderContainer> _pumpPanel(
  WidgetTester tester, {
  double height = 2300,
}) async {
  tester.view.physicalSize = Size(900, height + 100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewerEmailProvider.overrideWithValue('revisor@test.com'),
        reviewerUidProvider.overrideWithValue('uid-test'),
        imageReviewRepositoryProvider.overrideWithValue(
          InMemoryImageReviewRepository(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              height: height,
              child: const ImageReviewPanel(target: _target),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(ImageReviewPanel)),
  );
}

Finder _key(String key) => find.byKey(ValueKey(key));

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(_key(key)).controller!.text;

FocusNode _focusOf(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(of: _key(key), matching: find.byType(EditableText)),
    )
    .focusNode;

ReviewStatus _status(WidgetTester tester) =>
    tester.widget<ReviewStatusChip>(find.byType(ReviewStatusChip)).status;

Future<void> _fillValid(WidgetTester tester) async {
  await tester.enterText(_key('codigo-0'), 'A1');
  await tester.enterText(_key('numero-0'), '0123');
  await tester.tap(_key('agregar-numero-0'));
  await tester.pump();
  await tester.enterText(_key('total-0'), '9000');
  await tester.pump();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ElevatedButton, label));
  await tester.pumpAndSettle();
}

void main() {
  group('encabezado', () {
    testWidgets('muestra título y subtítulo con jornada, hora y número', (
      tester,
    ) async {
      await _pumpPanel(tester);

      expect(find.text('Registro de la imagen'), findsOneWidget);
      expect(
        find.text('Revisor · Jornada Mañana · 10:03 · Imagen #4'),
        findsOneWidget,
      );
    });

    testWidgets('chip de estado: Sin guardar → Guardado → Editando → Editado', (
      tester,
    ) async {
      await _pumpPanel(tester);
      expect(_status(tester), ReviewStatus.unsaved);
      expect(find.text('Sin guardar'), findsOneWidget);

      await _fillValid(tester);
      await _tapButton(tester, 'Guardar');
      expect(_status(tester), ReviewStatus.saved);
      expect(find.text('Guardado'), findsOneWidget);

      await _tapButton(tester, 'Editar');
      expect(_status(tester), ReviewStatus.editing);
      expect(find.text('Editando'), findsOneWidget);

      await tester.enterText(_key('total-0'), '12000');
      await _tapButton(tester, 'Guardar');
      expect(_status(tester), ReviewStatus.edited);
      expect(find.text('Editado'), findsOneWidget);
    });

    testWidgets('cada estado usa su color (fondo al 12 %, texto del color)', (
      tester,
    ) async {
      for (final status in ReviewStatus.values) {
        await tester.pumpWidget(
          MaterialApp(home: ReviewStatusChip(status: status)),
        );
        final text = tester.widget<Text>(find.text(status.label));
        expect(text.style!.color, status.color);
        final box = tester.widget<DecoratedBox>(
          find.descendant(
            of: find.byType(ReviewStatusChip),
            matching: find.byType(DecoratedBox),
          ),
        );
        expect(
          (box.decoration as BoxDecoration).color,
          status.color.withValues(alpha: 0.12),
        );
      }
      expect(
        ReviewStatus.values.map((s) => s.color).toSet(),
        hasLength(ReviewStatus.values.length),
      );
    });
  });

  group('pie: resumen', () {
    testWidgets('sin datos: 1 comprobante y suma \$0', (tester) async {
      await _pumpPanel(tester);

      expect(find.text('1 comprobante'), findsOneWidget);
      expect(find.text('Suma: \$0'), findsOneWidget);
    });

    testWidgets('suma los totales; los vacíos cuentan 0', (tester) async {
      await _pumpPanel(tester);

      await tester.enterText(_key('total-0'), '9000');
      await tester.pump();
      expect(find.text('Suma: \$9.000'), findsOneWidget);

      // Segundo comprobante con total vacío: no cambia la suma.
      await tester.tap(find.text('Agregar comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('2 comprobantes'), findsOneWidget);
      expect(find.text('Suma: \$9.000'), findsOneWidget);

      await tester.enterText(_key('total-1'), '500');
      await tester.pump();
      expect(find.text('Suma: \$9.500'), findsOneWidget);

      // Tercero, también vacío.
      await tester.tap(find.text('Agregar comprobante'));
      await tester.pumpAndSettle();
      expect(find.text('3 comprobantes'), findsOneWidget);
      expect(find.text('Suma: \$9.500'), findsOneWidget);

      // Quitar uno con datos baja la suma.
      await tester.tap(_key('quitar-0'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Quitar'));
      await tester.pumpAndSettle();
      expect(find.text('Suma: \$500'), findsOneWidget);
    });

    testWidgets('en lectura resume el registro guardado', (tester) async {
      await _pumpPanel(tester);
      await _fillValid(tester);
      await _tapButton(tester, 'Guardar');

      expect(find.text('1 comprobante'), findsOneWidget);
      expect(find.text('Suma: \$9.000'), findsOneWidget);
    });
  });

  group('agregar comprobante', () {
    testWidgets('hace scroll hasta la tarjeta nueva y enfoca su Código', (
      tester,
    ) async {
      final container = await _pumpPanel(tester, height: 600);
      final notifier =
          container.read(
              reviewDraftProvider((
                messageId: 'm1',
                rol: ReviewRole.revisor,
              )).notifier,
            )
            ..addComprobante()
            ..addComprobante();
      await tester.pumpAndSettle();
      expect(notifier, isNotNull);

      // Las tarjetas existentes o agregadas por código no roban el foco si
      // el panel ya estaba en pantalla: solo interesa el botón.
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      final offsetBefore = scrollable.position.pixels;

      await tester.tap(find.text('Agregar comprobante'));
      await tester.pumpAndSettle();

      expect(_key('codigo-3'), findsOneWidget);
      expect(_focusOf(tester, 'codigo-3').hasFocus, isTrue);
      expect(scrollable.position.pixels, greaterThan(offsetBefore));

      final panel = tester.getRect(find.byType(ImageReviewPanel));
      final field = tester.getRect(_key('codigo-3'));
      expect(field.top, greaterThanOrEqualTo(panel.top));
      expect(field.bottom, lessThanOrEqualTo(panel.bottom));
    });

    testWidgets('al abrir el panel ningún campo roba el foco', (tester) async {
      await _pumpPanel(tester);

      expect(_focusOf(tester, 'codigo-0').hasFocus, isFalse);
    });
  });

  group('teclado', () {
    testWidgets('Tab va de Código a Números y de Números a Total', (
      tester,
    ) async {
      await _pumpPanel(tester);

      await tester.tap(_key('codigo-0'));
      await tester.pump();
      expect(_focusOf(tester, 'codigo-0').hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusOf(tester, 'numero-0').hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_focusOf(tester, 'total-0').hasFocus, isTrue);
    });

    testWidgets('con números agregados, Tab sigue saltando chips y "+"', (
      tester,
    ) async {
      await _pumpPanel(tester);
      await tester.enterText(_key('numero-0'), '11');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(find.byType(InputChip), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(_focusOf(tester, 'total-0').hasFocus, isTrue);
    });

    testWidgets('Enter en Números agrega y mantiene el foco ahí', (
      tester,
    ) async {
      await _pumpPanel(tester);

      await tester.enterText(_key('numero-0'), '11');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(find.widgetWithText(InputChip, '11'), findsOneWidget);
      expect(_focusOf(tester, 'numero-0').hasFocus, isTrue);
    });

    Future<void> addNumbers(WidgetTester tester, List<String> numbers) async {
      for (final n in numbers) {
        await tester.enterText(_key('numero-0'), n);
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
      }
    }

    testWidgets('Backspace con el input vacío quita el último número', (
      tester,
    ) async {
      await _pumpPanel(tester);
      await addNumbers(tester, ['11', '22']);
      expect(find.byType(InputChip), findsNWidgets(2));

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(find.widgetWithText(InputChip, '22'), findsNothing);
      expect(find.widgetWithText(InputChip, '11'), findsOneWidget);
      expect(find.text('Números · 1'), findsOneWidget);
    });

    testWidgets('Backspace con texto en el input no quita chips', (
      tester,
    ) async {
      await _pumpPanel(tester);
      await addNumbers(tester, ['11', '22']);
      await tester.enterText(_key('numero-0'), '33');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(find.byType(InputChip), findsNWidgets(2));
    });

    testWidgets('Backspace sin números no hace nada', (tester) async {
      await _pumpPanel(tester);
      await tester.tap(_key('numero-0'));
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();

      expect(find.byType(InputChip), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('total con separador de miles', () {
    testWidgets('muestra "9.000" mientras se escribe y guarda solo dígitos', (
      tester,
    ) async {
      final container = await _pumpPanel(tester);

      await tester.enterText(_key('total-0'), '9000');
      await tester.pump();

      expect(_text(tester, 'total-0'), '9.000');
      expect(
        container
            .read(
              reviewDraftProvider((messageId: 'm1', rol: ReviewRole.revisor)),
            )
            .comprobantes
            .single
            .total,
        '9000',
      );
    });

    for (final pasted in ['9.000', '\$ 9000', '9 000']) {
      testWidgets('pegar "$pasted" deja "9.000"', (tester) async {
        final container = await _pumpPanel(tester);

        await tester.enterText(_key('total-0'), pasted);
        await tester.pump();

        expect(_text(tester, 'total-0'), '9.000');
        expect(
          container
              .read(
                reviewDraftProvider((messageId: 'm1', rol: ReviewRole.revisor)),
              )
              .comprobantes
              .single
              .total,
          '9000',
        );
      });
    }

    testWidgets('el tope de 12 dígitos cuenta dígitos, no caracteres', (
      tester,
    ) async {
      await _pumpPanel(tester);

      // 12 dígitos = 15 caracteres con puntos: entra completo.
      await tester.enterText(_key('total-0'), '123.456.789.012');
      await tester.pump();
      expect(_text(tester, 'total-0'), '123.456.789.012');

      // 13 dígitos: se recorta a 12.
      await tester.enterText(_key('total-0'), '1234567890123');
      await tester.pump();
      expect(_text(tester, 'total-0'), '123.456.789.012');
    });

    testWidgets('al editar un registro el total llega ya formateado', (
      tester,
    ) async {
      await _pumpPanel(tester);
      await _fillValid(tester);
      await _tapButton(tester, 'Guardar');
      await _tapButton(tester, 'Editar');

      expect(_text(tester, 'total-0'), '9.000');
      expect(find.text('Suma: \$9.000'), findsOneWidget);
    });
  });

  group('almacenamiento no disponible', () {
    testWidgets('el panel muestra el error, no queda cargando', (tester) async {
      const failure = Failure.storage(
        message: 'No se pudo abrir el almacenamiento local de este dispositivo',
      );
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewerEmailProvider.overrideWithValue('revisor@test.com'),
            reviewerUidProvider.overrideWithValue('uid-test'),
            imageReviewRepositoryProvider.overrideWithValue(
              const UnavailableImageReviewRepository(failure),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: SizedBox(
                width: 420,
                height: 900,
                child: ImageReviewPanel(target: _target),
              ),
            ),
          ),
        ),
      );
      // Sin reintentos: en pocos frames ya aparece el error.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(
        find.text(
          'No se pudo abrir el almacenamiento local de este dispositivo',
        ),
        findsOneWidget,
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
