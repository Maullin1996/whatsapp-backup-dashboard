import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/helpers/find_initial_index.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/custom_rich_text.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_information_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showSenderName;
  const MessageBubble({
    super.key,
    required this.message,
    required this.showSenderName,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final double maximumBubbleWidth = isMobile ? screenWidth * 0.92 : 420.0;

    return Container(
      constraints: BoxConstraints(maxWidth: maximumBubbleWidth),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            blurRadius: 0.5,
            offset: Offset(0, 0.2),
            color: Colors.black38,
            spreadRadius: 0.5,
            blurStyle: BlurStyle.normal,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSenderName && message.senderName.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                message.senderName,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.teal,
                ),
              ),
            ),
          if (message.isImage) _ImagePreview(storagePath: message.storagePath!),
          if (message.caption != null && message.caption!.isNotEmpty)
            CustomRichText(
              keyParam: 'Mensaje:  ',
              valueParam: message.caption!,
            ),
          MessageInformationWidget(message: message),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              message.messageDate,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends ConsumerWidget {
  final String storagePath;
  const _ImagePreview({required this.storagePath});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(imageUrlProvider(storagePath));
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final double imageDisplayWidth = isMobile ? screenWidth * 0.85 : 420.0;
    final int cacheDimension = isMobile ? 640 : 900;

    return GestureDetector(
      onTap: () {
        final items = ref.read(chatImageItemsProvider);
        if (items.isEmpty) return;

        final initialIndex = findInitialIndex(
          items: items,
          storagePath: storagePath,
        );

        context.push('/home/viewer/$initialIndex');
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: RepaintBoundary(
              child: ExtendedImage.network(
                urlAsync,
                width: imageDisplayWidth,
                cacheHeight: cacheDimension,
                cacheWidth: cacheDimension,
                fit: BoxFit.cover,
                cache: true,
                border: Border.all(color: Colors.transparent, width: 0),
                borderRadius: BorderRadius.circular(6),
                loadStateChanged: (ExtendedImageState state) {
                  switch (state.extendedImageLoadState) {
                    case LoadState.loading:
                      return Container(
                        height: 200,
                        color: Colors.black12,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    case LoadState.completed:
                      return null;
                    case LoadState.failed:
                      return GestureDetector(
                        onTap: () {
                          state.reLoadImage();
                        },
                        child: Container(
                          height: 200,
                          color: Colors.black12,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image, size: 40),
                                SizedBox(height: 8),
                                Text('Toca para reintentar'),
                              ],
                            ),
                          ),
                        ),
                      );
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
