import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/models/raw_message_model.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/helpers/to_domain.dart';

void main() {
  test('toDomain maps raw message and derives fields', () {
    final date = DateTime(2024, 1, 2, 15, 24);
    final raw = RawMessageModel(
      id: 'm1',
      senderName: 'Juan',
      chatJid: 'group_1',
      hasMedia: true,
      storagePath: 'images/pic.jpg',
      messageTimestamp: date.millisecondsSinceEpoch,
      localTime: '15:24',
      caption: 'hola',
    );

    final msg = toDomain(raw);

    expect(msg.id, 'm1');
    expect(msg.isImage, true);
    expect(msg.shift, shiftNames[Shift.night1]);
    expect(msg.messageDate, '15:24');
  });
}
