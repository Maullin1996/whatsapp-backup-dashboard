import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/controllers/messages_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';

import 'test_asset_bundle.dart';

/// Opciones del visor reutilizable (capa 2): las que usará la pantalla de
/// llenado. El comportamiento por defecto (el visor del chat) lo cubre
/// `image_detail_page_test.dart`, sin cambios.

ImageViewItem _item(String id) => ImageViewItem(
  messageId: id,
  chatJid: 'chat@g.us',
  storagePath: 'img_$id.png',
  senderName: 'Remitente $id',
  messageTimestamp: 1000,
  localTime: '10:00',
  shift: shiftNames[Shift.morning]!,
  fechaJornada: '2026-01-15',
);

/// De la primera a la última: índice 0 = la primera.
final _oldestFirstProvider = Provider<List<ImageViewItem>>(
  (_) => [_item('primera'), _item('segunda'), _item('tercera')],
);

class _CountingMessagesNotifier extends MessagesNotifier {
  static int loadMoreCalls = 0;

  @override
  Future<List<Message>> build() async => const [];

  @override
  Future<void> loadMore() async => loadMoreCalls++;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _pump(WidgetTester tester, ImageDetailPage page) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _CountingMessagesNotifier.loadMoreCalls = 0;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentReviewRoleProvider.overrideWithValue(null),
        reviewShiftsProvider.overrideWith((ref) async => const []),
        imageUrlProvider.overrideWith((ref, path) => 'http://localhost/$path'),
        messagesProvider.overrideWith(_CountingMessagesNotifier.new),
      ],
      child: MaterialApp(theme: AppTheme.light, home: page),
    ),
  );
  await _settle(tester);
}

String _shownSender() => RegExp(r'^Remitente (\w+)$')
    .firstMatch(
      find
          .byWidgetPredicate(
            (w) =>
                w is SelectableText && (w.data ?? '').startsWith('Remitente '),
          )
          .evaluate()
          .map((e) => (e.widget as SelectableText).data!)
          .single,
    )!
    .group(1)!;

void main() {
  setUpAll(setUpMockAssets);

  // Como en image_detail_page_test: la caché global de imágenes (avatar del
  // asset mockeado) filtra estado entre tests y descuadra la barra superior.
  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  group('reverse: false (de la primera a la última)', () {
    testWidgets('arranca en la primera; la flecha derecha avanza y la '
        'izquierda retrocede', (tester) async {
      await _pump(
        tester,
        ImageDetailPage(
          initialIndex: 0,
          items: _oldestFirstProvider,
          reverse: false,
          paginate: false,
        ),
      );
      expect(_shownSender(), 'primera');
      expect(find.text('1 de 3'), findsOneWidget);
      // En la primera no hay nada a la izquierda.
      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(_shownSender(), 'segunda');

      await tester.tap(find.byIcon(Icons.chevron_right));
      await _settle(tester);
      expect(_shownSender(), 'tercera');
      expect(find.text('3 de 3'), findsOneWidget);
      // En la última no hay nada a la derecha.
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await _settle(tester);
      expect(_shownSender(), 'segunda');
    });

    testWidgets('paginate: false no pide páginas del chat al llegar al '
        'final', (tester) async {
      await _pump(
        tester,
        ImageDetailPage(
          initialIndex: 0,
          items: _oldestFirstProvider,
          reverse: false,
          paginate: false,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);

      expect(_shownSender(), 'tercera');
      expect(_CountingMessagesNotifier.loadMoreCalls, 0);
    });
  });

  group('cierre y acciones', () {
    testWidgets('showClose: false oculta el botón y Esc no cierra', (
      tester,
    ) async {
      await _pump(
        tester,
        ImageDetailPage(
          initialIndex: 0,
          items: _oldestFirstProvider,
          reverse: false,
          paginate: false,
          showClose: false,
        ),
      );
      expect(find.byTooltip('Cerrar'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(find.byType(ImageDetailPage), findsOneWidget);
    });

    testWidgets('closeLabel muestra un botón con texto que llama a onClose; '
        'Esc también', (tester) async {
      var closes = 0;
      await _pump(
        tester,
        ImageDetailPage(
          initialIndex: 0,
          items: _oldestFirstProvider,
          reverse: false,
          paginate: false,
          closeLabel: 'Cerrar',
          onClose: () => closes++,
        ),
      );
      expect(find.widgetWithText(ElevatedButton, 'Cerrar'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cerrar'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(closes, 2);
    });

    testWidgets('las acciones extra van en la barra', (tester) async {
      await _pump(
        tester,
        ImageDetailPage(
          initialIndex: 0,
          items: _oldestFirstProvider,
          reverse: false,
          paginate: false,
          actions: [TextButton(onPressed: () {}, child: const Text('Subir'))],
        ),
      );
      expect(find.widgetWithText(TextButton, 'Subir'), findsOneWidget);
    });
  });
}
