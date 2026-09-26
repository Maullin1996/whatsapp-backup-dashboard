import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/pending_uploads_provider.dart';

/// Una jornada de un chat (la unidad que se sube).
typedef JornadaRef = ({String chatJid, String fechaJornada, String shift});

/// Avance de la subida de una jornada: [hechos] registros ya procesados de un
/// lote de [total] ([total] es 0 mientras aún se leen los pendientes).
typedef UploadProgress = ({int hechos, int total});

/// Resultado de subir una jornada.
class UploadOutcome {
  /// Subidos y marcados como sincronizados.
  final int subidos;

  /// No subidos (falló la subida o no se pudo marcar): siguen pendientes.
  final int fallidos;

  /// Se editaron mientras se subía: lo subido ya es viejo, así que siguen
  /// pendientes para subir la versión nueva.
  final int editados;

  /// Si no se pudieron ni leer los pendientes, el motivo; no se subió nada.
  final Failure? error;

  /// No se intentaron porque se salió del chat a mitad de la subida: siguen
  /// pendientes.
  final int sinIntentar;

  const UploadOutcome({
    this.subidos = 0,
    this.fallidos = 0,
    this.editados = 0,
    this.sinIntentar = 0,
    this.error,
  });

  /// Cuántos siguen pendientes tras esta subida.
  int get pendientes => fallidos + editados + sinIntentar;

  bool get todoSubido => error == null && pendientes == 0;
}

/// Sube los pendientes de una jornada. El estado son las jornadas que se están
/// subiendo ahora, con su avance (para mostrar "Subiendo X de N", deshabilitar
/// su botón y no subir dos veces a la vez).
///
/// La subida es registro por registro: cada uno que sube queda sincronizado
/// de inmediato, y los que fallan siguen pendientes; si se corta a mitad no
/// se pierde ni se duplica nada (el id del documento es fijo).
class ReviewUploadNotifier extends Notifier<Map<JornadaRef, UploadProgress>> {
  @override
  Map<JornadaRef, UploadProgress> build() => const {};

  bool isUploading(JornadaRef jornada) => state.containsKey(jornada);

  void _setProgress(JornadaRef jornada, int hechos, int total) {
    if (!ref.mounted) return;
    state = {...state, jornada: (hechos: hechos, total: total)};
  }

  /// La subida sigue "viva" mientras el notifier exista y el chat activo sea
  /// el de la jornada.
  bool _alive(JornadaRef jornada) =>
      ref.mounted && ref.read(activeChatProvider)?.chatJid == jornada.chatJid;

  /// Devuelve null si esa jornada ya se estaba subiendo.
  Future<UploadOutcome?> upload(JornadaRef jornada) async {
    if (state.containsKey(jornada)) return null;
    state = {...state, jornada: (hechos: 0, total: 0)};
    try {
      return await _upload(jornada);
    } finally {
      // El notifier puede haberse descartado (cambio de usuario).
      if (ref.mounted) {
        state = {...state}..remove(jornada);
        ref.invalidate(pendingUploadsProvider);
      }
    }
  }

  Future<UploadOutcome> _upload(JornadaRef jornada) async {
    // Se fijan al empezar: si cambia el usuario o el rol a mitad, esta subida
    // sigue con lo que tenía.
    final rol = ref.read(currentReviewRoleProvider);
    final repository = ref.read(imageReviewRepositoryProvider);
    final uploader = ref.read(reviewUploaderProvider);

    final pending = await repository.getPending(
      chatJid: jornada.chatJid,
      fechaJornada: jornada.fechaJornada,
      shift: jornada.shift,
      rol: rol,
    );
    final records = pending.fold((_) => null, (list) => list);
    if (records == null) {
      return UploadOutcome(error: pending.fold((f) => f, (_) => null));
    }

    var subidos = 0, fallidos = 0, editados = 0;
    for (var i = 0; i < records.length; i++) {
      // Salir del chat (o descartar el notifier) corta el lote: lo ya subido
      // queda sincronizado y el resto sigue pendiente para la próxima vez.
      if (!_alive(jornada)) {
        return UploadOutcome(
          subidos: subidos,
          fallidos: fallidos,
          editados: editados,
          sinIntentar: records.length - i,
        );
      }
      _setProgress(jornada, i, records.length);
      final record = records[i];
      final uploaded = await uploader.upload(record);
      if (uploaded.isLeft()) {
        fallidos++;
        continue;
      }

      // Si se re-guardó mientras subía, lo guardado ya es otra versión (cada
      // guardado pone un `registradoEn` nuevo): no se marca sincronizado.
      final current = await repository.getByMessageId(record.messageId, rol);
      final latest = current.fold((_) => null, (r) => r);
      if (latest == null || latest.registradoEn != record.registradoEn) {
        editados++;
        continue;
      }

      final marked = await repository.save(
        record.copyWith(estadoSync: EstadoSync.sincronizado),
      );
      if (marked.isLeft()) {
        // Se subió pero no quedó marcado: sigue pendiente y se volverá a subir
        // (mismo id de documento, no se duplica).
        fallidos++;
      } else {
        subidos++;
      }
    }
    return UploadOutcome(
      subidos: subidos,
      fallidos: fallidos,
      editados: editados,
    );
  }
}

final reviewUploadProvider =
    NotifierProvider<ReviewUploadNotifier, Map<JornadaRef, UploadProgress>>(
      ReviewUploadNotifier.new,
    );
