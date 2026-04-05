import 'dart:convert';
import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_bubble.dart';

Message _message({
  required String id,
  required String chatJid,
  required String senderName,
  required int ts,
  bool hasMedia = false,
  String? storagePath,
  String? caption,
}) {
  return Message(
    id: id,
    chatJid: chatJid,
    senderName: senderName,
    caption: caption,
    storagePath: storagePath,
    hasMedia: hasMedia,
    messageTimestamp: ts,
    localTime: '10:00',
    shift: 'AM',
    messageDate: '2026-04-05',
  );
}

void main() {
  HttpServer? server;
  late String baseUrl;

  setUpAll(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server!.port}';

    server!.listen((HttpRequest request) async {
      final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
      );
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType('image', 'png')
        ..add(bytes);
      await request.response.close();
    });
  });

  tearDownAll(() async {
    await server?.close(force: true);
  });

  Widget wrapWithRouter({
    required Message message,
    required bool showSenderName,
    List<ImageViewItem> imageItems = const [],
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) {
            return ProviderScope(
              overrides: [
                chatImageItemsProvider.overrideWithValue(imageItems),
                imageUrlProvider.overrideWith((ref, path) => '$baseUrl/$path'),
              ],
              child: Material(
                child: MessageBubble(
                  message: message,
                  showSenderName: showSenderName,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/home/viewer/:index',
          builder: (context, state) {
            final index = state.pathParameters['index']!;
            return Text('viewer $index');
          },
        ),
      ],
    );

    return MaterialApp.router(routerConfig: router);
  }

  testWidgets('shows sender name, caption and date', (tester) async {
    final message = _message(
      id: 'm1',
      chatJid: 'jid-1',
      senderName: 'Juan',
      ts: 1000,
      caption: 'Hola mundo',
    );

    await tester.pumpWidget(
      wrapWithRouter(message: message, showSenderName: true),
    );

    expect(find.text('Juan'), findsOneWidget);
    final richTextFinder = find.byWidgetPredicate(
      (widget) =>
          widget is SelectableText &&
          widget.textSpan?.toPlainText().contains('Hola mundo') == true,
    );
    expect(richTextFinder, findsOneWidget);
    expect(find.text('2026-04-05'), findsOneWidget);
  });

  testWidgets('hides sender name when showSenderName is false', (tester) async {
    final message = _message(
      id: 'm1',
      chatJid: 'jid-1',
      senderName: 'Juan',
      ts: 1000,
      caption: null,
    );

    await tester.pumpWidget(
      wrapWithRouter(message: message, showSenderName: false),
    );

    expect(find.text('Juan'), findsNothing);
  });

  testWidgets('renders image preview and navigates on tap', (tester) async {
    final message = _message(
      id: 'm-img',
      chatJid: 'jid-1',
      senderName: 'Ana',
      ts: 2000,
      hasMedia: true,
      storagePath: 'image-1.png',
    );

    final items = [
      ImageViewItem(
        storagePath: 'image-0.png',
        senderName: 'X',
        messageTimestamp: 1000,
        localTime: '09:00',
        shift: 'AM',
      ),
      ImageViewItem(
        storagePath: 'image-1.png',
        senderName: 'Ana',
        messageTimestamp: 2000,
        localTime: '10:00',
        shift: 'AM',
      ),
    ];

    await tester.pumpWidget(
      wrapWithRouter(message: message, showSenderName: true, imageItems: items),
    );

    expect(find.byType(ExtendedImage), findsOneWidget);

    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text('viewer 1'), findsOneWidget);
  });
}
