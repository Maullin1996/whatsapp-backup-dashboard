import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/helpers/jornadas_para_fecha.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_session_provider.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';

/// Botón "Llenar formularios" del listado de mensajes. Misma condición que
/// el panel del formulario del visor: ancho >= [AppBreakpoints.reviewForm],
/// rol activo y al menos una entrada de `reviewShifts` para el chat abierto
/// (mientras `reviewShifts` carga o falla, no aparece). Abre
/// [FillFormsDialog].
class FillFormsButton extends ConsumerWidget {
  const FillFormsButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.reviewForm) {
      return const SizedBox.shrink();
    }
    final chatJid = ref.watch(activeChatProvider.select((c) => c?.chatJid));
    if (chatJid == null || ref.watch(currentReviewRoleProvider) == null) {
      return const SizedBox.shrink();
    }
    final shifts = ref
        .watch(reviewShiftsProvider)
        .maybeWhen(data: (list) => list, orElse: () => const <ReviewShift>[]);
    if (!shifts.any((s) => s.chatJid == chatJid)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: ElevatedButton.icon(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const FillFormsDialog(),
        ),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('Llenar formularios'),
      ),
    );
  }
}

/// Elige fecha (flechas; sin flecha derecha en el día de hoy, sin límite
/// hacia atrás) y una de las jornadas asignadas en el chat abierto que
/// aplican a esa fecha ([jornadasParaFecha]). Tocar una jornada cierra el
/// diálogo y empieza la sesión de llenado: el guard del router lleva a
/// `/review`. No cuenta imágenes: todas las jornadas se pueden tocar.
class FillFormsDialog extends ConsumerStatefulWidget {
  const FillFormsDialog({super.key});

  @override
  ConsumerState<FillFormsDialog> createState() => _FillFormsDialogState();
}

class _FillFormsDialogState extends ConsumerState<FillFormsDialog> {
  /// "Hoy" con el mismo mecanismo que el Resumen.
  final DateTime _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _date = _today;

  void _moveDays(int days) => setState(
    () => _date = DateUtils.dateOnly(
      DateTime(_date.year, _date.month, _date.day + days),
    ),
  );

  void _open(String chatJid, String groupName, Shift shift) {
    // Se toma antes de cerrar: el diálogo se desmonta al cerrarse.
    final session = ref.read(reviewSessionProvider.notifier);
    Navigator.of(context).pop();
    session.start((
      jornada: (chatJid: chatJid, date: _date, shift: shift),
      groupName: groupName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(activeChatProvider);
    final shifts = ref
        .watch(reviewShiftsProvider)
        .maybeWhen(data: (list) => list, orElse: () => const <ReviewShift>[]);
    final jornadas = chat == null
        ? const <Shift>[]
        : jornadasParaFecha(shifts, chat.chatJid, _date);
    final isToday = !_date.isBefore(_today);

    return AlertDialog(
      title: const Text('Llenar formularios'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.emptyStateMaxWidth,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Día anterior',
                  onPressed: () => _moveDays(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    formatLongDate(_date),
                    textAlign: TextAlign.center,
                    style: AppTypography.headerTitle(context),
                  ),
                ),
                if (isToday)
                  // Mismo ancho que el botón: la fecha queda centrada.
                  const SizedBox(width: 48)
                else
                  IconButton(
                    tooltip: 'Día siguiente',
                    onPressed: () => _moveDays(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (jornadas.isEmpty)
              Text(
                'No tienes jornadas asignadas en este grupo para este día.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              )
            else
              for (final shift in jornadas)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: OutlinedButton(
                    onPressed: () =>
                        _open(chat!.chatJid, chat.groupName, shift),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          Text(
                            shortShiftName(shiftNames[shift]!),
                            style: AppTypography.headerTitle(context),
                          ),
                          if (shiftHoursText(shiftNames[shift]!)
                              case final hours?)
                            Text(
                              hours,
                              style: AppTypography.timestamp(context),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
