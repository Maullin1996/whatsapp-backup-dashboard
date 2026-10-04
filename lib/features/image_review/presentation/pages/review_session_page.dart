import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/jornada_images_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/pending_uploads_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_session_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/pending_upload_pill.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Lista que ve el visor: la de [jornadaImagesProvider] mientras tenga datos
/// (al recargar o tras un error conserva la última).
final _jornadaItemsProvider = Provider.autoDispose
    .family<List<ImageViewItem>, JornadaImagesKey>(
      (ref, key) =>
          ref.watch(jornadaImagesProvider(key)).value ??
          const <ImageViewItem>[],
    );

/// Pantalla de llenado (`/review`): solo las imágenes de una jornada de un
/// chat en un día, de la PRIMERA a la ÚLTIMA y en vivo, cada una con su
/// formulario (el mismo visor del chat, con sus mismas reglas de panel y de
/// navegación).
///
/// Sin botón de volver ni gesto ([PopScope]); el guard del router devuelve
/// aquí cualquier otra ruta mientras haya sesión ([reviewSessionProvider]).
/// Se sale con "Cerrar" (en el lugar del botón de cerrar la imagen, solo
/// cuando TODAS las imágenes tienen formulario, [reviewSessionCompleteProvider])
/// o recargando la página. "Subir" (en la cabecera) aparece con el primer
/// registro pendiente de la jornada y sube con `ReviewUploadNotifier`.
///
/// Con ancho < [AppBreakpoints.reviewForm] el visor oculta el panel (como en
/// el chat) y la navegación queda libre; un aviso arriba pide más ancho. La
/// sesión y la imagen actual no se pierden.
class ReviewSessionPage extends ConsumerWidget {
  const ReviewSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(reviewSessionProvider);
    // Sin sesión el guard ya está llevando a /home.
    if (session == null) return const Scaffold(body: SizedBox.shrink());

    final key = session.jornada;
    final images = ref.watch(jornadaImagesProvider(key));
    final complete = ref.watch(reviewSessionCompleteProvider(key));
    void close() => ref.read(reviewSessionProvider.notifier).end();

    final hasImages = images.hasValue && images.value!.isNotEmpty;
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.reviewForm;

    final Widget content;
    if (hasImages) {
      content = ImageDetailPage(
        initialIndex: 0,
        items: _jornadaItemsProvider(key),
        reverse: false,
        paginate: false,
        showClose: complete,
        closeLabel: 'Cerrar',
        onClose: close,
        reviewForm: true,
      );
    } else if (images.hasError && !images.hasValue) {
      content = _MessageState(
        icon: Icons.error_outline_rounded,
        message: mapFailureToMessage(images.error!),
        actionLabel: 'Reintentar',
        onAction: () => ref.invalidate(jornadaImagesProvider(key)),
      );
    } else if (images.hasValue) {
      content = const _MessageState(
        icon: Icons.image_outlined,
        message: 'Todavía no hay imágenes de esta jornada',
      );
    } else {
      content = const Center(child: CircularProgressIndicator());
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SessionHeader(
                session: session,
                actions: [
                  _UploadButton(jornada: key),
                  // Sin imágenes no hay visor: "Cerrar" va en la cabecera.
                  if (images.hasValue && !hasImages && complete)
                    ElevatedButton(
                      onPressed: close,
                      child: const Text('Cerrar'),
                    ),
                ],
              ),
              if (hasImages && narrow) const _NarrowNotice(),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

/// Qué se está llenando (grupo, jornada y fecha) y sus acciones.
class _SessionHeader extends StatelessWidget {
  final ReviewSession session;
  final List<Widget> actions;

  const _SessionHeader({required this.session, required this.actions});

  @override
  Widget build(BuildContext context) {
    final shift = session.jornada.shift;
    final label = shiftNames[shift] ?? legacyShiftNames[shift] ?? shift.name;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.accentTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${session.groupName} · ${shortShiftName(label)} · '
              '${formatLongDate(session.jornada.date)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headerTitle(context),
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: AppSpacing.sm),
            action,
          ],
        ],
      ),
    );
  }
}

/// "Subir" de esta jornada: la píldora de siempre (`PendingUploadPill`, que
/// confirma y sube con `ReviewUploadNotifier`), solo si la jornada tiene
/// registros pendientes del rol activo. Sale de `pendingUploadsProvider`
/// (pendientes del chat activo, que es el de la sesión).
class _UploadButton extends ConsumerWidget {
  final JornadaImagesKey jornada;

  const _UploadButton({required this.jornada});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fecha = fechaJornadaOf(jornada);
    final pending = ref.watch(pendingUploadsProvider).value ?? const [];
    for (final p in pending) {
      if (p.fechaJornada == fecha && shiftFromLabel(p.shift) == jornada.shift) {
        return PendingUploadPill(
          chatJid: jornada.chatJid,
          jornada: p,
          showJornada: false,
        );
      }
    }
    return const SizedBox.shrink();
  }
}

/// Aviso con ancho < [AppBreakpoints.reviewForm]: el formulario no cabe.
class _NarrowNotice extends StatelessWidget {
  const _NarrowNotice();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.warning;
    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const Icon(Icons.screen_rotation_rounded, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Gira la tablet o agranda la ventana para llenar el formulario.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío o de error: icono, mensaje y, opcionalmente, una acción.
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.emptyStateMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: AppSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTypography.headerTitle(context),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
