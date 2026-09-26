import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/pending_uploads_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_upload_notifier.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Una píldora por jornada del chat activo con registros pendientes de
/// subir. Al tocarla se confirma y se sube esa jornada (hoy simulado: ver
/// `reviewUploaderProvider`). Sin pendientes no ocupa espacio.
class PendingUploadIndicators extends ConsumerWidget {
  const PendingUploadIndicators({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatJid = ref.watch(activeChatProvider.select((c) => c?.chatJid));
    // `value` conserva la lista anterior mientras se recalcula: sin parpadeo.
    final jornadas = ref.watch(pendingUploadsProvider).value;
    if (chatJid == null || jornadas == null || jornadas.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final jornada in jornadas)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: _PendingUploadPill(
              key: ValueKey('${jornada.fechaJornada}|${jornada.shift}'),
              chatJid: chatJid,
              jornada: jornada,
            ),
          ),
      ],
    );
  }
}

class _PendingUploadPill extends ConsumerWidget {
  final String chatJid;
  final PendingJornada jornada;

  const _PendingUploadPill({
    super.key,
    required this.chatJid,
    required this.jornada,
  });

  static const _minHeight = 40.0;
  static const _progressSize = 14.0;
  static const _progressStroke = 2.0;

  JornadaRef get _ref => (
    chatJid: chatJid,
    fechaJornada: jornada.fechaJornada,
    shift: jornada.shift,
  );

  String get _jornadaLabel => shortShiftName(jornada.shift);

  static String _registros(int n) => n == 1 ? '1 registro' : '$n registros';

  Future<void> _onTap(BuildContext context, WidgetRef ref) async {
    // Se toman antes de esperar: la píldora puede desaparecer al terminar
    // (ya no quedan pendientes) y el SnackBar debe mostrarse igual.
    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(reviewUploadProvider.notifier);
    final date = jornadaDateLabel(jornada.fechaJornada) ?? 'hoy';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Subir registros'),
        content: Text(
          'Subir ${_registros(jornada.cantidad)} de $_jornadaLabel, $date',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Subir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final outcome = await notifier.upload(_ref);
    if (outcome == null) return; // ya se estaba subiendo
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(_resultSnackBar(outcome));
  }

  static SnackBar _resultSnackBar(UploadOutcome outcome) {
    final error = outcome.error;
    if (error != null) {
      return SnackBar(
        content: Text(mapFailureToMessage(error)),
        backgroundColor: AppColors.errorMessage,
      );
    }
    if (outcome.todoSubido) {
      return SnackBar(
        content: Text(
          outcome.subidos == 1
              ? '1 registro subido'
              : '${outcome.subidos} registros subidos',
        ),
        backgroundColor: AppColors.success,
      );
    }
    return SnackBar(
      content: Text(
        '${outcome.subidos} subidos, ${outcome.pendientes} no se pudieron '
        'subir; siguen pendientes',
      ),
      backgroundColor: AppColors.warning,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(currentReviewRoleProvider);
    final progress = ref.watch(reviewUploadProvider.select((m) => m[_ref]));
    final uploading = progress != null;

    final date = jornadaDateLabel(jornada.fechaJornada);
    final String label;
    if (progress != null) {
      final total = progress.total > 0 ? progress.total : jornada.cantidad;
      label = 'Subiendo ${progress.hechos} de $total';
    } else {
      label =
          '${rol.label} · $_jornadaLabel${date == null ? '' : ', $date'} · '
          '${jornada.cantidad} '
          '${jornada.cantidad == 1 ? 'pendiente' : 'pendientes'}';
    }

    const color = AppColors.warning;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: AppRadius.pillAll,
      child: InkWell(
        borderRadius: AppRadius.pillAll,
        onTap: uploading ? null : () => _onTap(context, ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (uploading)
                  SizedBox(
                    width: _progressSize,
                    height: _progressSize,
                    child: CircularProgressIndicator(
                      strokeWidth: _progressStroke,
                      color: color,
                      value: progress.total > 0
                          ? progress.hechos / progress.total
                          : null,
                    ),
                  )
                else
                  const Icon(
                    Icons.cloud_upload_rounded,
                    size: AppSpacing.lg,
                    color: color,
                  ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.badge.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
