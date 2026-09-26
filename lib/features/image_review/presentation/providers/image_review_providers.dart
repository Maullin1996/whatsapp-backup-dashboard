import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_state.dart';

/// Email del usuario autenticado (null si no hay sesión).
///
/// Los providers del feature dependen de este: cuando cambia (logout o
/// login con otra cuenta) se reconstruyen solos y otro usuario del mismo
/// navegador no ve ni guarda registros o borradores ajenos.
///
/// SUPOSICIÓN FRÁGIL: el reset asume que `authSessionProvider` solo emite
/// `loading` al arrancar la app (hoy solo su `build()` lo emite, y nadie lo
/// invalida ni escucha `idTokenChanges`/`authStateChanges`). Si en el futuro
/// se agrega un listener de esos streams (probable al implementar los roles
/// revisor/sumador) y la sesión pasa por `loading`, el email sería null un
/// instante y los borradores y registros se borrarían en silencio. Revisar
/// esto entonces (p. ej. conservando el último email conocido mientras la
/// sesión esté en `loading`).
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

/// Valor de `--dart-define=REVIEW_ROLE=...` (TEMPORAL, ver
/// [currentReviewRoleProvider]).
const String _reviewRoleDefine = String.fromEnvironment(
  'REVIEW_ROLE',
  defaultValue: 'revisor',
);

/// Convierte el valor de `REVIEW_ROLE` en un rol. Cualquier valor que no sea
/// `revisor` ni `sumador` cae en Revisor y lo avisa con `debugPrint`.
ReviewRole parseReviewRole(String value) {
  switch (value) {
    case 'revisor':
      return ReviewRole.revisor;
    case 'sumador':
      return ReviewRole.sumador;
    default:
      debugPrint(
        'REVIEW_ROLE inválido ("$value"): se usa "revisor". '
        'Valores permitidos: revisor, sumador.',
      );
      return ReviewRole.revisor;
  }
}

/// Rol con el que trabaja el usuario actual. Es el ÚNICO punto que decide el
/// rol activo: nada más en el feature lee el rol de otro lado.
///
/// TEMPORAL: hasta tener roles reales, sale del parámetro de compilación
/// `REVIEW_ROLE` (`flutter run --dart-define=REVIEW_ROLE=sumador`; sin él
/// arranca como Revisor). Más adelante se conecta a los custom claims
/// `revisor`/`sumador` del usuario autenticado (ver `image-review-roles`);
/// solo cambia este provider. En los tests se elige con un override.
final currentReviewRoleProvider = Provider<ReviewRole>(
  (ref) => parseReviewRole(_reviewRoleDefine),
);

/// Único punto donde se instancia el repositorio. Para pasar a Hive/SQLite
/// se cambia SOLO la implementación que se devuelve aquí.
final imageReviewRepositoryProvider = Provider<ImageReviewRepository>((ref) {
  ref.watch(reviewerEmailProvider); // descarta los datos al cambiar de sesión
  return InMemoryImageReviewRepository();
});

/// Registro guardado de una imagen para un rol (por [ReviewKey]); null si no
/// existe. Nunca devuelve el registro del otro rol. Un `Failure` del
/// repositorio queda como error del `AsyncValue`.
final savedRecordProvider =
    FutureProvider.family<ImageReviewRecord?, ReviewKey>((ref, key) async {
      final result = await ref
          .watch(imageReviewRepositoryProvider)
          .getByMessageId(key.messageId, key.rol);
      return result.fold((failure) => throw failure, (record) => record);
    });

/// La navegación del visor (en ambos sentidos) solo se permite si la imagen
/// ya tiene un registro guardado del rol indicado (completar los campos no
/// basta). Lo guardado por el otro rol no cuenta.
final canAdvanceProvider = Provider.family<bool, ReviewKey>((ref, key) {
  return ref.watch(savedRecordProvider(key)).value != null;
});

/// Borrador por imagen y rol. Vive en memoria durante la sesión: si el usuario
/// retrocede sin guardar, se conserva al volver; cada rol tiene el suyo.
final reviewDraftProvider =
    NotifierProvider.family<ReviewDraftNotifier, ReviewDraftState, ReviewKey>(
      ReviewDraftNotifier.new,
    );
