import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_remote_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';

/// Qué hizo [syncJornadaFromRemote] en el almacenamiento local.
typedef RemoteJornadaSyncResult = ({
  int escritos,
  int pendientesConservados,
  int borrados,
});

/// Trae a local lo subido de una jornada (lo subido es la fuente de verdad;
/// el almacenamiento local solo manda en lo PENDIENTE):
///
/// - Registro local pendiente de esa imagen: gana el local y no se toca.
/// - Si no: lo de Firebase se escribe en local como sincronizado (reemplaza
///   un sincronizado anterior, aunque difiera).
/// - Imagen de [jornadaMessageIds] sin registro legible en Firebase: si su
///   copia local está sincronizada, se borra; un pendiente nunca.
///
/// Si la lectura falla devuelve ese `Left` sin tocar nada. Si falla una
/// operación local, se detiene ahí con ese `Left` (lo ya hecho queda hecho:
/// cada paso deja el almacenamiento coherente).
Future<Either<Failure, RemoteJornadaSyncResult>> syncJornadaFromRemote({
  required ReviewRemoteRecordsDatasource remote,
  required ImageReviewRepository repository,
  required String chatJid,
  required String fechaJornada,
  required Shift shift,
  required ReviewRole rol,
  required Iterable<String> jornadaMessageIds,
}) async {
  final fetched = await remote.fetchJornada(
    chatJid: chatJid,
    fechaJornada: fechaJornada,
    shift: shift,
    rol: rol,
  );
  final readFailure = fetched.fold((f) => f, (_) => null);
  if (readFailure != null) return Left(readFailure);
  final models = fetched.getOrElse(() => const []);

  var escritos = 0, conservados = 0, borrados = 0;
  final remoteIds = <String>{};
  for (final model in models) {
    final record = model.record;
    remoteIds.add(record.messageId);
    final local = await repository.getByMessageId(record.messageId, rol);
    // Uno local ilegible se sobreescribe con lo de Firebase (es la verdad).
    final current = local.fold((_) => null, (r) => r);
    if (current?.estadoSync == EstadoSync.pendiente) {
      conservados++;
      continue;
    }
    final saved = await repository.save(record);
    final saveFailure = saved.fold((f) => f, (_) => null);
    if (saveFailure != null) return Left(saveFailure);
    escritos++;
  }

  for (final messageId in jornadaMessageIds) {
    if (remoteIds.contains(messageId)) continue;
    final deleted = await repository.deleteSynced(messageId, rol);
    final failure = deleted.fold((f) => f, (_) => null);
    if (failure != null) return Left(failure);
    if (deleted.getOrElse(() => false)) borrados++;
  }

  return Right((
    escritos: escritos,
    pendientesConservados: conservados,
    borrados: borrados,
  ));
}
