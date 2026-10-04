import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';

final chatImageItemsProvider = Provider<List<ImageViewItem>>((ref) {
  final messagesAsync = ref.watch(messagesProvider);

  return messagesAsync.maybeWhen(
    data: (messages) => messages
        .where((m) => m.isImage)
        .map(ImageViewItem.fromMessage)
        .toList(growable: false),
    orElse: () => const [],
  );
});
