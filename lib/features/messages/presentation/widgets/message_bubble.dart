import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:extended_image/extended_image.dart';
import 'package:go_router/go_router.dart';
import 'package:web/web.dart' as web;
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/helpers/find_initial_index.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/custom_rich_text.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/message_information_widget.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool showSenderName;
  final double screenWidth;

  const MessageBubble({
    super.key,
    required this.message,
    required this.showSenderName,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = screenWidth < AppBreakpoints.mobile;
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
          if (message.isImage)
            _MediaPreview(
              storagePath: message.storagePath!,
              displayWidth: isMobile ? screenWidth * 0.85 : 420.0,
              cacheDimension: isMobile ? 640 : 900,
            ),
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

class _MediaPreview extends ConsumerWidget {
  final String storagePath;
  final double displayWidth;
  final int cacheDimension;

  const _MediaPreview({
    required this.storagePath,
    required this.displayWidth,
    required this.cacheDimension,
  });

  String get _ext => storagePath.split('.').last.toLowerCase();

  bool get _isImage => ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(_ext);
  bool get _isVideo => ['mp4', 'webm', 'mov', 'avi'].contains(_ext);
  bool get _isAudio => ['mp3', 'ogg', 'm4a', 'aac', 'wav'].contains(_ext);
  bool get _isKnown => _isImage || _isVideo || _isAudio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!_isKnown) return const SizedBox.shrink();
    final url = ref.watch(imageUrlProvider(storagePath));

    if (_isImage) {
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
                  url,
                  width: displayWidth,
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
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      case LoadState.completed:
                        return null;
                      case LoadState.failed:
                        return GestureDetector(
                          onTap: () => state.reLoadImage(),
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

    // Video y Audio — botón simple que abre en el navegador
    final isVideo = _isVideo;
    final icon = isVideo ? Icons.play_circle_outline : Icons.audiotrack;
    final label = isVideo ? 'Ver video' : 'Reproducir audio';
    final color = isVideo ? Colors.blue.shade700 : Colors.green.shade700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Center(
        child: Container(
          width: displayWidth,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.open_in_new, color: color),
                onPressed: () {
                  web.HTMLAnchorElement()
                    ..href = url
                    ..target = '_blank'
                    ..click();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
