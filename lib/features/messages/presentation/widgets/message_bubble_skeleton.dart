import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Placeholder de una burbuja de mensaje.
///
/// El ancho es fijo y coincide con el de `MessageBubble`; lo que varía entre
/// ítems es el alto (imagen y líneas de texto), como en los mensajes reales.
class MessageBubbleSkeleton extends StatelessWidget {
  final int index;
  const MessageBubbleSkeleton({super.key, required this.index});

  static const _imageHeights = [200.0, 260.0, 170.0];
  static const _captionLines = [1, 2, 0];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < AppBreakpoints.mobile;
    final bubbleWidth = isMobile
        ? screenWidth * 0.92
        : AppSizes.messageBubbleMaxWidth;
    final imageWidth = isMobile
        ? screenWidth * 0.85
        : AppSizes.messageBubbleMaxWidth;

    final imageHeight = _imageHeights[index % _imageHeights.length];
    final captionLines = _captionLines[index % _captionLines.length];

    return Center(
      child: Container(
        width: bubbleWidth,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.buttonAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Remitente
            const _SkeletonBlock(width: 140, height: 14),
            const SizedBox(height: AppSpacing.xs),

            // Imagen
            Center(
              child: _SkeletonBlock(width: imageWidth, height: imageHeight),
            ),
            const SizedBox(height: 6),

            // Texto (0–2 líneas según el ítem)
            for (var i = 0; i < captionLines; i++) ...[
              _SkeletonBlock(
                width: i == captionLines - 1 ? bubbleWidth * 0.5 : null,
                height: 14,
              ),
              const SizedBox(height: 12),
            ],

            // Metadata
            const Align(
              alignment: Alignment.bottomRight,
              child: _SkeletonBlock(width: 60, height: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double? width;
  final double height;
  const _SkeletonBlock({this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
      ),
    );
  }
}
