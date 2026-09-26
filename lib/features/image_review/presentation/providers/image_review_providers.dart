import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_local_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/local_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/no_session_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/unavailable_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/sync/simulated_review_uploader.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_draft_state.dart';

/// Email del usuario autenticado (null si no hay sesión). Solo sirve para
/// auditoría (`registradoPor`); la identidad del usuario para separar datos
/// es [reviewerUidProvider].
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

/// uid del usuario autenticado (null si no hay sesión): el identificador
/// estable con el que se separan los datos locales de cada usuario.
///
/// Los borradores y el repositorio dependen de este: cuando cambia (logout o
/// login con otra cuenta) se reconstruyen solos. El repositorio pasa a
/// apuntar al almacenamiento del nuevo usuario SIN borrar el del anterior
/// (sus registros siguen ahí cuando vuelva a entrar); los borradores en
/// memoria sí se reinician.
///
/// SITUACIÓN REAL: el reset asume que `authSessionProvider` solo emite
/// `loading` al arrancar la app (hoy solo su `build()` lo emite, y nadie lo
/// invalida ni escucha `idTokenChanges`/`authStateChanges`). Si en el futuro
/// se agrega un listener de esos streams (probable al implementar los roles
/// revisor/sumador) y la sesión pasa por `loading`, el uid sería null un
/// instante. Con la persistencia local eso YA NO borra registros guardados
/// (el almacenamiento no se toca; reaparecen al volver el uid), pero sí
/// descartaría los borradores sin guardar y mostraría un instante el
/// repositorio "sin sesión". Si llega a pasar, conservar el último uid
/// conocido mientras la sesión esté en `loading`.
final reviewerUidProvider = Provider<String?>((ref) {
  return ref.watch(
    authSessionProvider.select(
      (session) => session.maybeWhen(
        authenticated: (user) => user.id,
        orElse: () => null,
      ),
    ),
  );
});

/// Resultado de abrir el almacenamiento local. Se abre UNA vez en `main.dart`
/// (antes de `runApp`) y se inyecta con un override; el fallo al abrirlo no
/// tumba la app (ver [imageReviewRepositoryProvider]).
final reviewLocalStorageProvider =
    Provider<Either<Failure, ReviewLocalDatasource>>(
      (ref) => throw UnimplementedError(
        'reviewLocalStorageProvider debe sobreescribirse en main.dart '
        '(o en los tests)',
      ),
    );

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

/// Único punto donde se instancia el repositorio. Para cambiar de
/// almacenamiento se cambia SOLO lo que se devuelve aquí.
///
/// - Con sesión y almacenamiento abierto: el repositorio persistente de ESE
///   usuario ([reviewerUidProvider]). Al cambiar de usuario apunta a sus
///   datos sin borrar los del anterior.
/// - Sin sesión: repositorio vacío (lecturas vacías, guardar no autorizado).
/// - Almacenamiento que no se pudo abrir: repositorio "no disponible", cuyo
///   error ya muestra el panel.
final imageReviewRepositoryProvider = Provider<ImageReviewRepository>((ref) {
  final uid = ref.watch(reviewerUidProvider);
  if (uid == null) return const NoSessionImageReviewRepository();
  return ref
      .watch(reviewLocalStorageProvider)
      .fold<ImageReviewRepository>(
        UnavailableImageReviewRepository.new,
        (datasource) => LocalImageReviewRepository(datasource, uid: uid),
      );
});

/// Único punto donde se instancia el uploader. SIMULADO: imprime en consola lo
/// que se subiría y no toca Firestore. La conexión real (otra implementación
/// de [ReviewUploader]) no se activa sin autorización explícita.
final reviewUploaderProvider = Provider<ReviewUploader>(
  (ref) => const SimulatedReviewUploader(),
);

/// Registro guardado de una imagen para un rol (por [ReviewKey]); null si no
/// existe. Nunca devuelve el registro del otro rol. Un `Failure` del
/// repositorio queda como error del `AsyncValue`.
///
/// Sin reintento automático: Riverpod 3 reintenta con backoff todo lo que no
/// sea un `Error`, y un `Failure` de almacenamiento (registro ilegible, no se
/// pudo abrir) no es transitorio; reintentar dejaría el panel en "cargando"
/// en vez de mostrar el error.
final savedRecordProvider =
    FutureProvider.family<ImageReviewRecord?, ReviewKey>((ref, key) async {
      final result = await ref
          .watch(imageReviewRepositoryProvider)
          .getByMessageId(key.messageId, key.rol);
      return result.fold((failure) => throw failure, (record) => record);
    }, retry: (retryCount, error) => null);

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
