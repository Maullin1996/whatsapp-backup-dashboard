import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/image_review_panel.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/review_status_chip.dart';

const _target = ImageReviewTarget(
  messageId: 'm1',
  chatJid: 'chat@g.us',
  shift: 'Jornada Mañana',
  localTime: '10:03',
  shiftImageIndex: 4,
);

const _email = 'sumador@test.com';

/// Rol activo de los tests, modificable para simular un cambio de rol.
class _RoleNotifier extends Notifier<ReviewRole> {
  @override
  ReviewRole build() => ReviewRole.sumador;

  void set(ReviewRole rol) => state = rol;
}

final _roleProvider = NotifierProvider<_RoleNotifier, ReviewRole>(
  _RoleNotifier.new,
);

Future<ProviderContainer> _pumpPanel(
  WidgetTester tester, {
  ReviewRole role = ReviewRole.sumador,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewerEmailProvider.overrideWithValue(_email),
        currentReviewRoleProvider.overrideWith(
          (ref) => ref.watch(_roleProvider),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 420,
              height: 2300,
              child: ImageReviewPanel(target: _target),
            ),
          ),
        ),
      ),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(ImageReviewPanel)),
  );
  container.read(_roleProvider.notifier).set(role);
  await tester.pumpAndSettle();
  return container;
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

Future<void> _fill(
  WidgetTester tester, {
  String codigo = 'A1',
  String total = '9000',
}) async {
  await tester.enterText(_key('codigo-0'), codigo);
  await tester.enterText(_key('total-0'), total);
  await tester.pump();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ElevatedButton, label));
  await tester.pumpAndSettle();
}

Future<ImageReviewRecord?> _saved(ProviderContainer c, ReviewRole rol) async {
  final result = await c
      .read(imageReviewRepositoryProvider)
      .getByMessageId('m1', rol);
  return result.fold((_) => fail('no se esperaba Left'), (r) => r);
}

void main() {
  group('formulario del Sumador', () {
    testWidgets('solo tiene código y total: sin campo ni chips de números', (
      tester,
    ) async {
      await _pumpPanel(tester);

      expect(_key('codigo-0'), findsOneWidget);
      expect(_key('total-0'), findsOneWidget);
      expect(_key('numero-0'), findsNothing);
      expect(_key('agregar-numero-0'), findsNothing);
      expect(find.byType(InputChip), findsNothing);
      expect(find.textContaining('Números'), findsNothing);
      // Igual que el Revisor: anotaciones y agregar comprobante.
      expect(_key('anotaciones'), findsOneWidget);
      expect(find.text('Agregar comprobante'), findsOneWidget);
    });

    testWidgets('el rol va primero en el subtítulo del encabezado', (
      tester,
    ) async {
      await _pumpPanel(tester);

      expect(
        find.text('Sumador · Jornada Mañana · 10:03 · Imagen #4'),
        findsOneWidget,
      );
      expect(_status(tester), ReviewStatus.unsaved);
    });

    testWidgets('Tab va de Código a Total', (tester) async {
      await _pumpPanel(tester);

      await tester.tap(_key('codigo-0'));
      await tester.pump();
      expect(_focusOf(tester, 'codigo-0').hasFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(_focusOf(tester, 'total-0').hasFocus, isTrue);
    });

    testWidgets('el pie muestra "N comprobantes" y "Suma: \$X"', (
      tester,
    ) async {
      await _pumpPanel(tester);
      expect(find.text('1 comprobante'), findsOneWidget);
      expect(find.text('Suma: \$0'), findsOneWidget);

      await tester.enterText(_key('total-0'), '9000');
      await tester.pump();
      await tester.tap(find.text('Agregar comprobante'));
      await tester.pumpAndSettle();
      await tester.enterText(_key('total-1'), '500');
      await tester.pump();

      expect(find.text('2 comprobantes'), findsOneWidget);
      expect(find.text('Suma: \$9.500'), findsOneWidget);
    });

    testWidgets('validación: sin datos, error de código y total; sin regla de '
        'números', (tester) async {
      final container = await _pumpPanel(tester);

      await _tapButton(tester, 'Guardar');

      expect(find.text('Comprobante 1: ingresa el código'), findsOneWidget);
      expect(find.text('Obligatorio'), findsNWidgets(2)); // código y total
      expect(find.text('Agrega al menos un número'), findsNothing);
      expect(await _saved(container, ReviewRole.sumador), isNull);
    });

    testWidgets('validación: total 0 -> "Debe ser mayor que 0"', (
      tester,
    ) async {
      await _pumpPanel(tester);
      await _fill(tester, total: '0');

      await _tapButton(tester, 'Guardar');

      expect(find.text('Debe ser mayor que 0'), findsOneWidget);
      expect(
        find.text('Comprobante 1: el total debe ser mayor que 0'),
        findsOneWidget,
      );
    });

    testWidgets('guardar: registro del Sumador, sin números, con su correo', (
      tester,
    ) async {
      final container = await _pumpPanel(tester);
      await _fill(tester, codigo: '  Antioquia ', total: '9000');
      await tester.enterText(_key('anotaciones'), '  no se lee ');

      await _tapButton(tester, 'Guardar');

      final record = await _saved(container, ReviewRole.sumador);
      expect(record, isNotNull);
      expect(record!.rol, ReviewRole.sumador);
      expect(record.registradoPor, _email);
      expect(record.editado, isFalse);
      expect(record.form.comprobantes.single.codigo, 'Antioquia');
      expect(record.form.comprobantes.single.total, 9000);
      expect(record.form.comprobantes.single.numeros, isEmpty);
      expect(record.form.anotaciones, 'no se lee');
      expect(_status(tester), ReviewStatus.saved);
    });
  });

  group('lectura y edición del Sumador', () {
    Future<ProviderContainer> saved(WidgetTester tester) async {
      final container = await _pumpPanel(tester);
      await _fill(tester);
      await tester.enterText(_key('anotaciones'), 'nota');
      await _tapButton(tester, 'Guardar');
      return container;
    }

    testWidgets('la vista de solo lectura no muestra números', (tester) async {
      await saved(tester);

      expect(find.text('A1'), findsOneWidget);
      expect(find.text('\$9.000'), findsOneWidget);
      expect(find.text('nota'), findsOneWidget);
      expect(find.textContaining('Números'), findsNothing);
      expect(find.byType(Chip), findsNothing);
      expect(find.text('1 comprobante'), findsOneWidget);
      expect(find.text('Suma: \$9.000'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Editar'), findsOneWidget);
    });

    testWidgets('Editar abre el formulario sin números y re-guardar marca '
        'editado', (tester) async {
      final container = await saved(tester);

      await _tapButton(tester, 'Editar');
      expect(_status(tester), ReviewStatus.editing);
      expect(_text(tester, 'codigo-0'), 'A1');
      expect(_text(tester, 'total-0'), '9.000');
      expect(_key('numero-0'), findsNothing);

      await tester.enterText(_key('total-0'), '12000');
      await _tapButton(tester, 'Guardar');

      final record = await _saved(container, ReviewRole.sumador);
      expect(record!.editado, isTrue);
      expect(record.rol, ReviewRole.sumador);
      expect(record.form.comprobantes.single.total, 12000);
      expect(record.form.comprobantes.single.numeros, isEmpty);
      expect(_status(tester), ReviewStatus.edited);
      expect(find.text('Suma: \$12.000'), findsOneWidget);
    });
  });

  group('cambio de rol: cada uno ve solo lo suyo', () {
    testWidgets('lo guardado como Revisor no aparece como Sumador', (
      tester,
    ) async {
      final container = await _pumpPanel(tester, role: ReviewRole.revisor);
      expect(
        find.text('Revisor · Jornada Mañana · 10:03 · Imagen #4'),
        findsOneWidget,
      );
      await tester.enterText(_key('codigo-0'), 'REV');
      await tester.enterText(_key('numero-0'), '0123');
      await tester.tap(_key('agregar-numero-0'));
      await tester.pump();
      await tester.enterText(_key('total-0'), '9000');
      await tester.pump();
      await _tapButton(tester, 'Guardar');
      expect(_status(tester), ReviewStatus.saved);
      expect(find.text('REV'), findsOneWidget);

      container.read(_roleProvider.notifier).set(ReviewRole.sumador);
      await tester.pumpAndSettle();

      // Formulario vacío del Sumador: no ve el registro del Revisor.
      expect(_status(tester), ReviewStatus.unsaved);
      expect(find.text('REV'), findsNothing);
      expect(_text(tester, 'codigo-0'), isEmpty);
      expect(_text(tester, 'total-0'), isEmpty);
      expect(_key('numero-0'), findsNothing);
      expect(
        find.text('Sumador · Jornada Mañana · 10:03 · Imagen #4'),
        findsOneWidget,
      );
    });

    testWidgets('lo guardado como Sumador no aparece como Revisor', (
      tester,
    ) async {
      final container = await _pumpPanel(tester);
      await _fill(tester, codigo: 'SUM', total: '500');
      await _tapButton(tester, 'Guardar');
      expect(find.text('SUM'), findsOneWidget);

      container.read(_roleProvider.notifier).set(ReviewRole.revisor);
      await tester.pumpAndSettle();

      expect(_status(tester), ReviewStatus.unsaved);
      expect(find.text('SUM'), findsNothing);
      expect(_text(tester, 'codigo-0'), isEmpty);
      expect(_key('numero-0'), findsOneWidget);
    });

    testWidgets('el borrador sin guardar de cada rol se conserva al alternar', (
      tester,
    ) async {
      final container = await _pumpPanel(tester, role: ReviewRole.revisor);
      await tester.enterText(_key('codigo-0'), 'DEL-REVISOR');
      await tester.pump();

      container.read(_roleProvider.notifier).set(ReviewRole.sumador);
      await tester.pumpAndSettle();
      expect(_text(tester, 'codigo-0'), isEmpty);
      await tester.enterText(_key('codigo-0'), 'DEL-SUMADOR');
      await tester.pump();

      container.read(_roleProvider.notifier).set(ReviewRole.revisor);
      await tester.pumpAndSettle();
      expect(_text(tester, 'codigo-0'), 'DEL-REVISOR');

      container.read(_roleProvider.notifier).set(ReviewRole.sumador);
      await tester.pumpAndSettle();
      expect(_text(tester, 'codigo-0'), 'DEL-SUMADOR');
    });
  });
}
