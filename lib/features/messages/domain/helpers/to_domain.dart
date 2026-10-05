import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/models/raw_message_model.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';

Message toDomain(RawMessageModel model) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    model.messageTimestamp,
  ).toLocal();

  // Etiqueta del visor (en un hueco entre jornadas, "Fuera de jornada X").
  final shiftLabel = shiftViewerLabel(date);

  return Message(
    id: model.id,
    chatJid: model.chatJid,
    senderName: model.senderName,
    hasMedia: model.hasMedia,
    messageTimestamp: model.messageTimestamp,
    localTime: model.localTime,
    caption: model.caption,
    storagePath: model.storagePath,
    shift: shiftLabel,
    messageDate: date.toString().substring(11, 16),
    isEdited: model.isEdited,
    shiftImageIndex: model.shiftImageIndex,
  );
}
