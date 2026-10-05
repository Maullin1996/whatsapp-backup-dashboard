import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';

class ImageViewItem {
  final String messageId;
  final String chatJid;
  final String storagePath;
  final String senderName;
  final int messageTimestamp;
  final String localTime;
  final String shift;

  /// Día de la jornada (`yyyy-MM-dd`), derivado de [messageTimestamp] en hora
  /// local. No es `Message.messageDate` (que guarda la hora).
  final String fechaJornada;
  final bool isEdited;
  final int? shiftImageIndex;

  ImageViewItem({
    required this.messageId,
    required this.chatJid,
    required this.storagePath,
    required this.senderName,
    required this.messageTimestamp,
    required this.localTime,
    required this.shift,
    required this.fechaJornada,
    this.isEdited = false,
    this.shiftImageIndex,
  });

  /// Item del visor para un mensaje con imagen ([Message.isImage]).
  factory ImageViewItem.fromMessage(Message m) => ImageViewItem(
    messageId: m.id,
    chatJid: m.chatJid,
    storagePath: m.storagePath!,
    senderName: m.senderName,
    messageTimestamp: m.messageTimestamp,
    localTime: m.localTime,
    shift: m.shift,
    fechaJornada: fechaJornadaDe(m.messageTimestamp),
    isEdited: m.isEdited,
    shiftImageIndex: m.shiftImageIndex,
  );
}
