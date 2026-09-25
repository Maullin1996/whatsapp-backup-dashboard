import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/image_review_panel.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/controllers/messages_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/guarded_action.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_controler_actions.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/nav_button.dart';

import 'test_asset_bundle.dart';

const _blockedMessage = 'Guarda el formulario para continuar';

/// `pumpAndSettle` no termina aquí: la imagen de red nunca carga y su spinner
/// anima para siempre. Se avanza un tiempo fijo (cubre transiciones de ruta,
/// SnackBar y el desplazamiento del pager).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

ImageViewItem _itemFor(String id) => ImageViewItem(
  messageId: id,
  chatJid: 'chat@g.us',
  storagePath: 'img_$id.png',
  senderName: 'Remitente $id',
  messageTimestamp: 1000,
  localTime: '10:00',
  shift: 'Jornada Mañana',
);

/// Índice 0 = el más nuevo (como en la app).
ImageViewItem _item(int i) => _itemFor('m$i');

/// Lista de imágenes del chat, modificable como lo haría el tiempo real.
class _ItemsNotifier extends Notifier<List<ImageViewItem>> {
  @override
  List<ImageViewItem> build() => [_item(0), _item(1), _item(2)];

  /// Las imágenes nuevas llegan al principio (más nuevas = índice 0).
  void insertAtFront(List<ImageViewItem> newer) => state = [...newer, ...state];

  void replace(List<ImageViewItem> items) => state = items;
}

final _itemsProvider = NotifierProvider<_ItemsNotifier, List<ImageViewItem>>(
  _ItemsNotifier.new,
);

class _CountingMessagesNotifier extends MessagesNotifier {
  static int loadMoreCalls = 0;

  @override
  Future<List<Message>> build() async => const [];

  @override
  Future<void> loadMore() async => loadMoreCalls++;
}

/// Abre el visor (initialIndex 1 de 3 imágenes) desde una pantalla de inicio.
Future<void> _openViewer(
  WidgetTester tester, {
  required double width,
  int initialIndex = 1,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reviewerEmailProvider.overrideWithValue('revisor@test.com'),
        chatImageItemsProvider.overrideWith((ref) => ref.watch(_itemsProvider)),
        imageUrlProvider.overrideWith((ref, path) => 'http://localhost/$path'),
        messagesProvider.overrideWith(_CountingMessagesNotifier.new),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ImageDetailPage(initialIndex: initialIndex),
                  ),
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await _settle(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(ImageDetailPage)));

Future<void> _saveRecordFor(WidgetTester tester, String messageId) async {
  final container = _container(tester);
  await container
      .read(imageReviewRepositoryProvider)
      .save(
        ImageReviewRecord(
          messageId: messageId,
          chatJid: 'chat@g.us',
          shift: 'Jornada Mañana',
          form: const ImageReviewForm(
            comprobantes: [
              Comprobante(codigo: 'A1', numeros: ['0123'], total: 9000),
            ],
          ),
          registradoEn: DateTime(2026),
          registradoPor: 'revisor@test.com',
        ),
      );
  container.invalidate(savedRecordProvider(messageId));
  await _settle(tester);
}

Future<void> _saveRecordsForAll(WidgetTester tester) async {
  for (final id in ['m0', 'm1', 'm2']) {
    await _saveRecordFor(tester, id);
  }
}

Future<void> _key(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await _settle(tester);
}

/// El pager va en reverse: arrastrar a la izquierda va al índice−1 (más nuevo).
Future<void> _swipeLeft(WidgetTester tester) async {
  await tester.fling(
    find.byType(ExtendedImageGesturePageView),
    const Offset(-500, 0),
    1500,
  );
  await _settle(tester);
}

/// Arrastrar a la derecha va al índice+1 (más viejo).
Future<void> _swipeRight(WidgetTester tester) async {
  await tester.fling(
    find.byType(ExtendedImageGesturePageView),
    const Offset(500, 0),
    1500,
  );
  await _settle(tester);
}

Finder _pos(int n, [int total = 3]) => find.text('$n de $total');

/// La imagen `id` está centrada en el pager (es la que se ve).
void _expectViewing(WidgetTester tester, String id) {
  final pager = tester.getCenter(find.byType(ExtendedImageGesturePageView));
  // A ≥ 840 px el panel usa la misma ValueKey(messageId): se busca en el pager.
  final image = find.descendant(
    of: find.byType(ExtendedImageGesturePageView),
    matching: find.byKey(ValueKey(id)),
  );
  expect(image, findsOneWidget, reason: 'la imagen $id debe estar construida');
  expect(tester.getCenter(image).dx, closeTo(pager.dx, 1));
}

void _insertAtFront(WidgetTester tester, List<String> ids) => _container(tester)
    .read(_itemsProvider.notifier)
    .insertAtFront([for (final id in ids) _itemFor(id)]);

void _replaceItems(WidgetTester tester, List<String> ids) => _container(
  tester,
).read(_itemsProvider.notifier).replace([for (final id in ids) _itemFor(id)]);

Finder _chevron(IconData icon) => find.widgetWithIcon(NavButton, icon);

String _text(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.byKey(ValueKey(key))).controller!.text;

Future<void> _fillAndSave(
  WidgetTester tester, {
  String codigo = 'A1',
  String numero = '7',
  String total = '500',
}) async {
  await tester.enterText(find.byKey(const ValueKey('codigo-0')), codigo);
  await tester.enterText(find.byKey(const ValueKey('numero-0')), numero);
  await tester.tap(find.byKey(const ValueKey('agregar-numero-0')));
  await tester.pump();
  await tester.enterText(find.byKey(const ValueKey('total-0')), total);
  await tester.pump();
  await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
  await _settle(tester);
}

void main() {
  setUpAll(setUpMockAssets);

  setUp(() => _CountingMessagesNotifier.loadMoreCalls = 0);

  // La caché global de imágenes (avatar del asset mockeado) filtra estado
  // entre tests y descuadra el layout de la barra superior.
  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  // Las teclas no cambian: → va al índice−1 y ← al índice+1 (más viejo).
  group('< 840 px: el visor queda como siempre', () {
    testWidgets('sin panel, sin bloqueo: teclas y chevrons navegan', (
      tester,
    ) async {
      await _openViewer(tester, width: 700);

      expect(find.byType(ImageReviewPanel), findsNothing);
      expect(_pos(2), findsOneWidget);
      for (final icon in [Icons.chevron_left, Icons.chevron_right]) {
        final chevron = tester.widget<NavButton>(_chevron(icon));
        expect(chevron.enabled, isTrue);
        expect(chevron.tooltip, isNull);
      }

      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_pos(1), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_pos(2), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_pos(3), findsOneWidget);
      expect(find.text(_blockedMessage), findsNothing);
    });

    testWidgets('el swipe navega libre hacia ambos lados', (tester) async {
      await _openViewer(tester, width: 700);

      await _swipeLeft(tester);
      expect(_pos(1), findsOneWidget);
      await _swipeRight(tester);
      expect(_pos(2), findsOneWidget);
      await _swipeRight(tester);
      expect(_pos(3), findsOneWidget);
      expect(find.text(_blockedMessage), findsNothing);
    });
  });

  group('≥ 840 px sin registro guardado: bloqueo en ambos sentidos', () {
    testWidgets('muestra el panel', (tester) async {
      await _openViewer(tester, width: 1200);

      expect(find.byType(ImageReviewPanel), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);
    });

    testWidgets('→ no navega y muestra el SnackBar', (tester) async {
      await _openViewer(tester, width: 1200);

      await _key(tester, LogicalKeyboardKey.arrowRight);

      expect(_pos(2), findsOneWidget);
      expect(find.text(_blockedMessage), findsOneWidget);
    });

    testWidgets('← no navega y muestra el SnackBar', (tester) async {
      await _openViewer(tester, width: 1200);

      await _key(tester, LogicalKeyboardKey.arrowLeft);

      expect(_pos(2), findsOneWidget);
      expect(find.text(_blockedMessage), findsOneWidget);
    });

    testWidgets('los dos chevrons están deshabilitados, con tooltip y avisan', (
      tester,
    ) async {
      await _openViewer(tester, width: 1200);

      for (final icon in [Icons.chevron_left, Icons.chevron_right]) {
        final chevron = tester.widget<NavButton>(_chevron(icon));
        expect(chevron.enabled, isFalse);
        expect(chevron.tooltip, _blockedMessage);

        await tester.tap(_chevron(icon));
        await _settle(tester);

        expect(_pos(2), findsOneWidget);
        expect(find.text(_blockedMessage), findsOneWidget);
      }
    });

    testWidgets('el swipe hacia la izquierda no cambia de página', (
      tester,
    ) async {
      await _openViewer(tester, width: 1200);

      await _swipeLeft(tester);

      expect(_pos(2), findsOneWidget);
      expect(find.text(_blockedMessage), findsOneWidget);
    });

    testWidgets('el swipe hacia la derecha no cambia de página', (
      tester,
    ) async {
      await _openViewer(tester, width: 1200);

      await _swipeRight(tester);

      expect(_pos(2), findsOneWidget);
      expect(find.text(_blockedMessage), findsOneWidget);
    });

    testWidgets('cerrar el visor siempre está permitido (botón)', (
      tester,
    ) async {
      await _openViewer(tester, width: 1200);

      await tester.tap(find.byTooltip('Cerrar'));
      await _settle(tester);

      expect(find.byType(ImageDetailPage), findsNothing);
    });
  });

  group('≥ 840 px con registro guardado: navegación libre', () {
    testWidgets('las dos flechas navegan', (tester) async {
      await _openViewer(tester, width: 1200);
      await _saveRecordsForAll(tester);

      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_pos(1), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_pos(2), findsOneWidget);
      expect(find.text(_blockedMessage), findsNothing);
    });

    testWidgets('los dos chevrons están habilitados y navegan', (tester) async {
      await _openViewer(tester, width: 1200);
      await _saveRecordFor(tester, 'm1');

      for (final icon in [Icons.chevron_left, Icons.chevron_right]) {
        final chevron = tester.widget<NavButton>(_chevron(icon));
        expect(chevron.enabled, isTrue);
        expect(chevron.tooltip, isNull);
      }
      await tester.tap(_chevron(Icons.chevron_right));
      await _settle(tester);
      expect(_pos(1), findsOneWidget);
    });

    testWidgets('el swipe navega hacia ambos lados', (tester) async {
      await _openViewer(tester, width: 1200);
      await _saveRecordsForAll(tester);

      await _swipeLeft(tester);
      expect(_pos(1), findsOneWidget);
      await _swipeRight(tester);
      expect(_pos(2), findsOneWidget);
      expect(find.text(_blockedMessage), findsNothing);
    });

    testWidgets('un swipe que empieza en una imagen registrada llega a una sin '
        'registro sin avisar; desde ahí queda bloqueado', (tester) async {
      await _openViewer(tester, width: 1200);
      await _saveRecordFor(tester, 'm1'); // solo la actual tiene registro

      // El índice cambia a mitad del arrastre: el bloqueo se decide con la
      // imagen donde empezó el gesto, no con la de destino.
      await _swipeLeft(tester);
      expect(_pos(1), findsOneWidget);
      expect(find.text(_blockedMessage), findsNothing);

      // Ahora la actual (m0) no tiene registro: se bloquea.
      await _swipeRight(tester);
      expect(_pos(1), findsOneWidget);
      expect(find.text(_blockedMessage), findsOneWidget);
    });

    testWidgets('en modo Editar con cambios sin guardar se navega y el '
        'borrador se conserva', (tester) async {
      await _openViewer(tester, width: 1200);
      await _saveRecordFor(tester, 'm1');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Editar'));
      await _settle(tester);
      await tester.enterText(find.byKey(const ValueKey('total-0')), '12000');
      await tester.pump();

      await tester.tap(_chevron(Icons.chevron_left));
      await _settle(tester);

      expect(_pos(3), findsOneWidget);
      expect(find.text(_blockedMessage), findsNothing);
      expect(
        _container(
          tester,
        ).read(reviewDraftProvider('m1')).comprobantes.single.total,
        '12000',
      );
    });
  });

  group('≥ 840 px con un campo de texto enfocado', () {
    testWidgets('← y → no navegan ni avisan', (tester) async {
      await _openViewer(tester, width: 1200);
      await tester.enterText(find.byKey(const ValueKey('total-0')), '12');

      await _key(tester, LogicalKeyboardKey.arrowRight);
      await _key(tester, LogicalKeyboardKey.arrowLeft);

      expect(_pos(2), findsOneWidget);
      expect(find.text(_blockedMessage), findsNothing);
    });

    testWidgets('Esc solo quita el foco; sin campo enfocado cierra el visor', (
      tester,
    ) async {
      await _openViewer(tester, width: 1200);
      await tester.enterText(find.byKey(const ValueKey('total-0')), '12');
      expect(isTextFieldFocused(), isTrue);

      await _key(tester, LogicalKeyboardKey.escape);

      expect(isTextFieldFocused(), isFalse);
      expect(find.byType(ImageDetailPage), findsOneWidget);

      // Cerrar sigue permitido aunque la navegación esté bloqueada.
      await _key(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ImageDetailPage), findsNothing);
    });
  });

  testWidgets('cada imagen tiene su propio borrador y sus controllers', (
    tester,
  ) async {
    // A = m1, B = m2 (más vieja). Para salir de A hay que guardarla.
    await _openViewer(tester, width: 1200);
    await _fillAndSave(tester, codigo: 'A1');
    expect(find.text('Código: A1'), findsOneWidget);

    // Editar A y dejar un cambio sin guardar; navegar sigue permitido.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Editar'));
    await _settle(tester);
    await tester.enterText(find.byKey(const ValueKey('codigo-0')), 'AAA2');
    await tester.pump();

    await tester.tap(_chevron(Icons.chevron_left));
    await _settle(tester);
    expect(_pos(3), findsOneWidget);

    // B muestra su propio borrador (vacío), no el de A.
    expect(_text(tester, 'codigo-0'), isEmpty);
    expect(_text(tester, 'total-0'), isEmpty);

    // Para salir de B también hay que guardarla.
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_pos(3), findsOneWidget);
    expect(find.text(_blockedMessage), findsOneWidget);
    await _fillAndSave(tester, codigo: 'BBB');
    expect(find.text('Código: BBB'), findsOneWidget);

    // Al volver a A sigue su borrador sin guardar (y el foco volvió al visor).
    await _key(tester, LogicalKeyboardKey.arrowRight);
    expect(_pos(2), findsOneWidget);
    expect(_text(tester, 'codigo-0'), 'AAA2');
  });

  group('llega una imagen nueva por tiempo real: el visor se ancla por '
      'messageId', () {
    for (final width in [1200.0, 700.0]) {
      final label = width >= 840 ? '≥ 840 px' : '< 840 px';

      testWidgets('$label: sigue mostrando la misma imagen; índice y total '
          'se actualizan', (tester) async {
        await _openViewer(tester, width: width); // B = m1 (índice 1)
        _expectViewing(tester, 'm1');
        expect(_pos(2), findsOneWidget);

        _insertAtFront(tester, ['n1']);
        await _settle(tester);

        _expectViewing(tester, 'm1');
        expect(_pos(3, 4), findsOneWidget); // índice 2 de 4
        expect(find.text('Remitente m1', findRichText: true), findsWidgets);
        expect(_CountingMessagesNotifier.loadMoreCalls, 0);
        expect(find.text(_blockedMessage), findsNothing);
      });

      testWidgets('$label: varias imágenes de una vez (batching) no mueven la '
          'imagen actual', (tester) async {
        await _openViewer(tester, width: width);

        _insertAtFront(tester, ['n1', 'n2', 'n3']);
        await _settle(tester);

        _expectViewing(tester, 'm1');
        expect(_pos(5, 6), findsOneWidget);
        expect(_CountingMessagesNotifier.loadMoreCalls, 0);
      });

      testWidgets('$label: si la actual es la última, la inserción tampoco la '
          'mueve', (tester) async {
        await _openViewer(tester, width: width, initialIndex: 2);
        _expectViewing(tester, 'm2');

        _insertAtFront(tester, ['n1']);
        await _settle(tester);

        _expectViewing(tester, 'm2');
        expect(_pos(4, 4), findsOneWidget);
      });
    }

    testWidgets('≥ 840 px: el panel sigue siendo el de la imagen actual, con '
        'su texto y su foco; el borrador de la nueva está vacío', (
      tester,
    ) async {
      await _openViewer(tester, width: 1200);
      await tester.enterText(find.byKey(const ValueKey('codigo-0')), 'AAA');
      await tester.pump();
      final focusBefore = FocusManager.instance.primaryFocus;
      expect(isTextFieldFocused(), isTrue);

      _insertAtFront(tester, ['n1']);
      await _settle(tester);

      expect(
        tester
            .widget<ImageReviewPanel>(find.byType(ImageReviewPanel))
            .target
            .messageId,
        'm1',
      );
      expect(_text(tester, 'codigo-0'), 'AAA');
      expect(isTextFieldFocused(), isTrue);
      expect(FocusManager.instance.primaryFocus, same(focusBefore));
      expect(
        _container(
          tester,
        ).read(reviewDraftProvider('n1')).comprobantes.single.codigo,
        isEmpty,
      );
      expect(_CountingMessagesNotifier.loadMoreCalls, 0);

      // Lo que se sigue tecleando queda en el borrador de la imagen actual.
      await tester.enterText(find.byKey(const ValueKey('codigo-0')), 'AAAB');
      await tester.pump();
      expect(
        _container(
          tester,
        ).read(reviewDraftProvider('m1')).comprobantes.single.codigo,
        'AAAB',
      );
      expect(
        _container(
          tester,
        ).read(reviewDraftProvider('n1')).comprobantes.single.codigo,
        isEmpty,
      );
    });

    testWidgets('≥ 840 px sin registro: el salto no lo bloquea el bloqueo de '
        'navegación ni muestra el aviso; la navegación sigue bloqueada', (
      tester,
    ) async {
      await _openViewer(tester, width: 1200);

      _insertAtFront(tester, ['n1', 'n2']);
      await _settle(tester);

      // El salto programático llegó a destino sin aviso.
      _expectViewing(tester, 'm1');
      expect(find.text(_blockedMessage), findsNothing);

      // Y el bloqueo sigue funcionando en ambos sentidos.
      await _key(tester, LogicalKeyboardKey.arrowRight);
      expect(_pos(4, 5), findsOneWidget);
      expect(find.text(_blockedMessage), findsOneWidget);
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_pos(4, 5), findsOneWidget);

      for (final icon in [Icons.chevron_left, Icons.chevron_right]) {
        expect(tester.widget<NavButton>(_chevron(icon)).enabled, isFalse);
        await tester.tap(_chevron(icon));
        await _settle(tester);
        expect(_pos(4, 5), findsOneWidget);
      }

      await _swipeLeft(tester);
      expect(_pos(4, 5), findsOneWidget);
      await _swipeRight(tester);
      expect(_pos(4, 5), findsOneWidget);
      _expectViewing(tester, 'm1');
    });

    testWidgets('≥ 840 px con registro: tras la inserción se navega libre en '
        'ambos sentidos', (tester) async {
      await _openViewer(tester, width: 1200);
      await _saveRecordFor(tester, 'm1');

      _insertAtFront(tester, ['n1']);
      await _settle(tester);
      _expectViewing(tester, 'm1');

      await _key(tester, LogicalKeyboardKey.arrowRight); // hacia el índice−1
      expect(_pos(2, 4), findsOneWidget);
      _expectViewing(tester, 'm0'); // lista: [n1, m0, m1, m2]
      expect(find.text(_blockedMessage), findsNothing);

      // m0 no tiene registro: desde ahí se bloquea.
      await _key(tester, LogicalKeyboardKey.arrowLeft);
      expect(_pos(2, 4), findsOneWidget);
      expect(find.text(_blockedMessage), findsOneWidget);
    });

    testWidgets(
      '< 840 px: tras la inserción se navega libre (teclas y swipe)',
      (tester) async {
        await _openViewer(tester, width: 700);

        _insertAtFront(tester, ['n1']);
        await _settle(tester);
        _expectViewing(tester, 'm1');

        await _key(tester, LogicalKeyboardKey.arrowRight);
        expect(_pos(2, 4), findsOneWidget);
        await _swipeRight(tester);
        expect(_pos(3, 4), findsOneWidget);
        expect(find.text(_blockedMessage), findsNothing);
      },
    );

    testWidgets('si la imagen actual desaparece de la lista, se queda en la '
        'misma posición (acotada) sin romperse', (tester) async {
      await _openViewer(tester, width: 700);

      // m1 (índice 1) desaparece: en el índice 1 ahora está m2.
      _replaceItems(tester, ['m0', 'm2']);
      await _settle(tester);
      _expectViewing(tester, 'm2');
      expect(_pos(2, 2), findsOneWidget);

      // Si era la última y desaparece, se acota a la nueva última.
      _replaceItems(tester, ['m0']);
      await _settle(tester);
      _expectViewing(tester, 'm0');
      expect(_pos(1, 1), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('GuardedAction', () {
    testWidgets('con un campo enfocado no dispara 0, -, = ni las flechas; sin '
        'campo sí', (tester) async {
      final invoked = <Type>[];
      final viewerFocus = FocusNode();
      addTearDown(viewerFocus.dispose);

      GuardedAction<T> action<T extends Intent>() => GuardedAction<T>(
        onInvoke: (_) {
          invoked.add(T);
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FocusableActionDetector(
              autofocus: true,
              focusNode: viewerFocus,
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.digit0):
                    const ZoomResetIntent(),
                LogicalKeySet(LogicalKeyboardKey.minus): const ZoomOutIntent(),
                LogicalKeySet(LogicalKeyboardKey.equal): const ZoomInIntent(),
                LogicalKeySet(LogicalKeyboardKey.arrowRight):
                    const NextImageIntent(),
                LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                    const PreviousImageIntent(),
              },
              actions: {
                ZoomResetIntent: action<ZoomResetIntent>(),
                ZoomOutIntent: action<ZoomOutIntent>(),
                ZoomInIntent: action<ZoomInIntent>(),
                NextImageIntent: action<NextImageIntent>(),
                PreviousImageIntent: action<PreviousImageIntent>(),
              },
              child: const TextField(key: ValueKey('campo')),
            ),
          ),
        ),
      );
      const keys = [
        LogicalKeyboardKey.digit0,
        LogicalKeyboardKey.minus,
        LogicalKeyboardKey.equal,
        LogicalKeyboardKey.arrowRight,
        LogicalKeyboardKey.arrowLeft,
      ];

      // Campo enfocado: ninguna se invoca (el evento llega al campo).
      await tester.tap(find.byKey(const ValueKey('campo')));
      await tester.pump();
      expect(isTextFieldFocused(), isTrue);
      for (final key in keys) {
        await tester.sendKeyEvent(key);
      }
      expect(invoked, isEmpty);

      // Foco en el visor: las cinco se invocan.
      viewerFocus.requestFocus();
      await tester.pump();
      expect(isTextFieldFocused(), isFalse);
      for (final key in keys) {
        await tester.sendKeyEvent(key);
      }
      expect(invoked, [
        ZoomResetIntent,
        ZoomOutIntent,
        ZoomInIntent,
        NextImageIntent,
        PreviousImageIntent,
      ]);
    });
  });
}
