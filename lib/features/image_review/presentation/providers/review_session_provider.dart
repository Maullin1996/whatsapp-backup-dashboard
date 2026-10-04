import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/jornada_images_provider.dart';

/// Jornada que se está llenando en `/review` y el nombre de su grupo (para
/// la cabecera).
typedef ReviewSession = ({JornadaImagesKey jornada, String groupName});

/// Sesión de llenado activa, o `null`. Vive SOLO en memoria: mientras exista,
/// el guard del router no deja salir de `/review` (ver `computeAuthRedirect`);
/// recargar la página la borra y con ella la única salida además de "Cerrar".
/// Se vacía sola si cambia el usuario (logout o login con otra cuenta).
class ReviewSessionNotifier extends Notifier<ReviewSession?> {
  @override
  ReviewSession? build() {
    ref.watch(reviewerUidProvider);
    return null;
  }

  void start(ReviewSession session) => state = session;

  void end() => state = null;
}

final reviewSessionProvider =
    NotifierProvider<ReviewSessionNotifier, ReviewSession?>(
      ReviewSessionNotifier.new,
    );

/// "Cerrar" de `/review`: `true` cuando TODAS las imágenes de la lista tienen
/// registro guardado del rol activo (el mismo `savedRecordProvider` que
/// decide el bloqueo de navegación: guardado en local, pendiente o ya
/// subido). Con la lista vacía también es `true` (decisión del usuario: no hay
/// nada que llenar). Una imagen nueva sin registro lo vuelve `false` hasta que
/// se guarde. Mientras la lista o algún registro carga, o con un error, es
/// `false`; sin rol activo, también.
final reviewSessionCompleteProvider = Provider.autoDispose
    .family<bool, JornadaImagesKey>((ref, key) {
      final images = ref.watch(jornadaImagesProvider(key));
      if (!images.hasValue) return false;
      final rol = ref.watch(currentReviewRoleProvider);
      if (rol == null) return false;
      var complete = true;
      // Se observan todas (no se corta en la primera) para enterarse de cada
      // guardado.
      for (final item in images.value!) {
        final saved = ref.watch(
          savedRecordProvider((messageId: item.messageId, rol: rol)),
        );
        if (saved.value == null) complete = false;
      }
      return complete;
    });
