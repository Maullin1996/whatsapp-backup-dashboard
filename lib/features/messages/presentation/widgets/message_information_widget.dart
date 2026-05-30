import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';

import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/custom_rich_text.dart';
import '../../domain/entities/message.dart';

class MessageInformationWidget extends ConsumerWidget {
  final Message message;

  const MessageInformationWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        CustomRichText(
          keyParam: 'Enviado por:  ',
          valueParam: message.senderName,
        ),
        const SizedBox(height: 8),
        CustomRichText(keyParam: 'Jornada:  ', valueParam: message.shift),
        const SizedBox(height: 8),
        CustomRichText(keyParam: 'Fecha:  ', valueParam: message.localTime),
        const SizedBox(height: 8),
        if (message.isImage && message.shiftImageIndex != null)
          CustomRichText(
            keyParam: 'Imagen de jornada:  ',
            valueParam: '# ${message.shiftImageIndex}',
          ),
        const SizedBox(height: 8),
        // CustomRichText(
        //   keyParam: 'timestamp:  ',
        //   valueParam: message.messageTimestamp.toString(),
        // ),
        // const SizedBox(height: 8),
        if (message.isEdited)
          Text(
            'Editado',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.errorMessage,
            ),
          ),
      ],
    );
  }
}
