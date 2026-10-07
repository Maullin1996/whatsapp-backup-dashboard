import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/jornada_images_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/pending_uploads_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_session_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_upload_notifier.dart';
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

/// La lectura de lo subido fue negada: casi siempre porque la cuenta ya no
/// tiene asignada esa jornada. Reintentar sirve solo si un administrador
/// corrige la asignación; recargar es la salida.
const String _unauthorizedMessage =
    'No tienes asignada esta jornada (o tu cuenta no tiene permiso para ver '
    'sus formularios). Pídele a un administrador que revise tu asignación. '
    'Recarga la página para salir.';

/// Pantalla de llenado (`/review`): solo las imágenes de una jornada de un
/// chat en un día, de la PRIMERA a la ÚLTIMA y en vivo, cada una con su
/// formulario (el mismo visor del chat, con sus mismas reglas de panel y de
/// navegación).
///
/// Al entrar trae lo ya subido de la jornada ([reviewSessionSyncProvider]);
/// mientras tanto, o si falla, no muestra el visor (no se puede llenar). El
/// visor abre en la primera imagen sin formulario.
///
/// Sin botón de volver ni gesto ([PopScope]); el guard del router devuelve
/// aquí cualquier otra ruta mientras haya sesión ([reviewSessionProvider]).
/// Se sale con "Cerrar" (en el lugar del botón de cerrar la imagen, o en la
/// cabecera si no hay visor) o recargando la página. "Cerrar" se ve SIEMPRE,
/// pero deshabilitado mientras se sube la jornada o la mezcla de lo ya subido
/// no terminó. Si hay registros sin subir de la jornada, pregunta antes
/// ([_onClose]): subir y salir, o salir sin subir. "Subir" (en la cabecera)
/// aparece con el primer registro pendiente de la jornada y sube con
/// `ReviewUploadNotifier`.
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
    void close() => _onClose(context, ref, key);

    final hasImages = images.hasValue && images.value!.isNotEmpty;
    final narrow = MediaQuery.sizeOf(context).width < AppBreakpoints.reviewForm;

    // Una subida y la mezcla de la misma jornada nunca se cruzan (la mezcla
    // borraría o pisaría en local lo que la subida acaba de marcar):
    // - "Subir" solo aparece con la mezcla terminada sin error (con la lista
    //   vacía no hay mezcla);
    // - "Cerrar" (y Esc) queda deshabilitado mientras se sube esta jornada y
    //   mientras la mezcla no termina: salir y volver a entrar arrancaría otra
    //   mezcla con la subida en curso.
    final fecha = fechaJornadaOf(key);
    final uploading = ref.watch(
      reviewUploadProvider.select(
        (jornadas) => jornadas.keys.any(
          (j) =>
              j.chatJid == key.chatJid &&
              j.fechaJornada == fecha &&
              shiftFromLabel(j.shift) == key.shift,
        ),
      ),
    );
    final sync = hasImages ? ref.watch(reviewSessionSyncProvider(key)) : null;
    final canUpload = images.hasValue && (sync == null || sync is AsyncData);
    final closeEnabled = canUpload && !uploading;

    final Widget content;
    if (sync != null) {
      // No se llena nada hasta traer lo ya subido (lo subido manda).
      content = sync.when(
        data: (initialIndex) => ImageDetailPage(
          initialIndex: initialIndex,
          items: _jornadaItemsProvider(key),
          reverse: false,
          paginate: false,
          showClose: true,
          closeEnabled: closeEnabled,
          closeLabel: 'Cerrar',
          onClose: close,
          reviewForm: true,
        ),
        error: (error, _) => _MessageState(
          icon: error is UnauthorizedFailure
              ? Icons.lock_outline_rounded
              : Icons.error_outline_rounded,
          message: error is UnauthorizedFailure
              ? _unauthorizedMessage
              : 'No se pudieron traer los formularios ya subidos de esta '
                    'jornada: ${mapFailureToMessage(error)}',
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(reviewSessionSyncProvider(key)),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
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
                  if (canUpload) _UploadButton(jornada: key),
                  // Sin visor (sin imágenes, cargando o con error): "Cerrar" va en
                  // la cabecera.
                  if (sync is! AsyncData)
                    ElevatedButton(
                      onPressed: closeEnabled ? close : null,
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

/// "Cerrar": sin registros sin subir de la jornada sale directo; con ellos
/// pregunta ("Subir a Firebase y salir" / "Salir sin subir"; tocar fuera lo
/// cierra y deja en la pantalla). "Subir a Firebase y salir" sube con
/// `ReviewUploadNotifier` (sin el diálogo de confirmación de la píldora) y
/// sale solo si no quedó ningún registro pendiente; si no, se queda y muestra
/// el mismo aviso de la píldora.
Future<void> _onClose(
  BuildContext context,
  WidgetRef ref,
  JornadaImagesKey key,
) async {
  final session = ref.read(reviewSessionProvider.notifier);
  final upload = ref.read(reviewUploadProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  final fecha = fechaJornadaOf(key);

  // Si no se pueden leer los pendientes se pregunta igual (lo seguro).
  PendingJornada? pending;
  try {
    final all = await ref.read(pendingUploadsProvider.future);
    for (final p in all) {
      if (p.fechaJornada == fecha && shiftFromLabel(p.shift) == key.shift) {
        pending = p;
        break;
      }
    }
    if (pending == null) return session.end();
  } catch (_) {
    pending = null;
  }
  if (!context.mounted) return;

  final uploadFirst = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('¿Salir de la revisión?'),
      content: const Text(
        'Lo que no se haya subido a la nube se puede perder.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Salir sin subir'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Subir a Firebase y salir'),
        ),
      ],
    ),
  );
  if (uploadFirst == null) return; // tocó fuera: se queda
  if (!uploadFirst) return session.end();

  // Sin la lista no hay jornada que subir: se queda (no se inventa una).
  final p = pending;
  if (p == null) return;
  final outcome = await upload.upload((
    chatJid: key.chatJid,
    fechaJornada: p.fechaJornada,
    shift: p.shift,
  ));
  if (outcome == null) return; // ya se estaba subiendo o no hay rol
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(PendingUploadPill.resultSnackBar(outcome));
  if (outcome.todoSubido) session.end();
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
