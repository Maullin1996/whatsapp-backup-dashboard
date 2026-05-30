import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';

final chatImageItemsProvider = Provider<List<ImageViewItem>>((ref) {
  final messagesAsync = ref.watch(messagesProvider);

  return messagesAsync.maybeWhen(
    data: (messages) => messages
        .where((m) => m.isImage)
        .map(
          (m) => ImageViewItem(
            storagePath: m.storagePath!,
            senderName: m.senderName,
            messageTimestamp: m.messageTimestamp,
            localTime: m.localTime,
            shift: m.shift,
            isEdited: m.isEdited,
            shiftImageIndex: m.shiftImageIndex,
          ),
        )
        .toList(growable: false),
    orElse: () => const [],
  );
});
