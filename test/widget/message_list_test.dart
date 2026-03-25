import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/controllers/messages_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_list.dart';

import 'test_asset_bundle.dart';

bool _anySelectableTextContains(WidgetTester tester, String value) {
  final widgets = tester.widgetList<SelectableText>(find.byType(SelectableText));
  for (final widget in widgets) {
    final span = widget.textSpan;
    if (span != null && span.toPlainText().contains(value)) {
      return true;
    }
  }
  return false;
}

class FakeMessagesNotifier extends MessagesNotifier {
  FakeMessagesNotifier(this._messages);

  final List<Message> _messages;

  @override
  Future<List<Message>> build() async => _messages;
}

void main() {
  setUpAll(setUpMockAssets);

  testWidgets('MessageList renders messages content', (tester) async {
    final now = DateTime.now();
    final messages = [
      Message(
        id: 'm1',
        chatJid: 'c1',
        senderName: 'Ana',
        caption: 'Hola mundo',
        storagePath: null,
        hasMedia: false,
        messageTimestamp: now.millisecondsSinceEpoch,
        localTime: '10:30',
        shift: 'Jornada Mañana (06:00 – 10:54)',
        messageDate: '10:30',
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagesProvider.overrideWith(() => FakeMessagesNotifier(messages)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MessageList()),
        ),
      ),
    );

    await tester.pump();

    expect(_anySelectableTextContains(tester, 'Mensaje:  Hola mundo'), true);
    expect(_anySelectableTextContains(tester, 'Enviado por:  Ana'), true);
    expect(find.text('10:30'), findsWidgets);
  });
}
