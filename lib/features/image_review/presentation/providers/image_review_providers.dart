import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_state.dart';

/// Email del usuario autenticado (null si no hay sesión).
///
/// Los providers del feature dependen de este: cuando cambia (logout o
/// login con otra cuenta) se reconstruyen solos y otro usuario del mismo
/// navegador no ve ni guarda registros o borradores ajenos.
final reviewerEmailProvider = Provider<String?>((ref) {
  return ref.watch(
    authSessionProvider.select(
      (session) => session.maybeWhen(
        authenticated: (user) => user.email,
        orElse: () => null,
      ),
    ),
  );
});

/// Único punto donde se instancia el repositorio. Para pasar a Hive/SQLite
/// se cambia SOLO la implementación que se devuelve aquí.
final imageReviewRepositoryProvider = Provider<ImageReviewRepository>((ref) {
  ref.watch(reviewerEmailProvider); // descarta los datos al cambiar de sesión
  return InMemoryImageReviewRepository();
});

/// Registro guardado de una imagen (por messageId); null si no existe.
/// Un `Failure` del repositorio queda como error del `AsyncValue`.
final savedRecordProvider = FutureProvider.family<ImageReviewRecord?, String>((
  ref,
  messageId,
) async {
  final result = await ref
      .watch(imageReviewRepositoryProvider)
      .getByMessageId(messageId);
  return result.fold((failure) => throw failure, (record) => record);
});

/// La navegación hacia adelante solo se permite si la imagen ya tiene un
/// registro guardado (completar los campos no basta).
final canAdvanceProvider = Provider.family<bool, String>((ref, messageId) {
  return ref.watch(savedRecordProvider(messageId)).value != null;
});

/// Borrador por messageId. Vive en memoria durante la sesión: si el usuario
/// retrocede sin guardar, se conserva al volver.
final reviewDraftProvider =
    NotifierProvider.family<ReviewDraftNotifier, ReviewDraftState, String>(
      ReviewDraftNotifier.new,
    );
