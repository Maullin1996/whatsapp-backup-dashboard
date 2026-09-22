import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

class MessageBubbleSkeleton extends StatelessWidget {
  final int index;
  const MessageBubbleSkeleton({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    final maxWidths = [260.0, 300.0, 340.0];
    final maxWidth = maxWidths[index % maxWidths.length];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.tileAll,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Remitente
              Container(
                width: 140,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Imagen
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Texto
              Container(
                width: maxWidth * 0.7,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                ),
              ),
              const SizedBox(height: 6),

              // Metadata
              Align(
                alignment: Alignment.bottomRight,
                child: Container(
                  width: 60,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.thumbnail),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
