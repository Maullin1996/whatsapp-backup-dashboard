import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Almacenamiento local (`hive_ce`: IndexedDB en web) de los registros de
/// revisión. Nunca se llama desde un Notifier: solo desde el repositorio.
///
/// Un único `LazyBox<String>` para todos los usuarios; la separación está en
/// las claves, que empiezan por el `uid`. Cada valor es el JSON del
/// [ImageReviewRecordModel]. Dos familias de claves:
///
/// - registro: `r|uid|rol|messageId`
/// - índice de pendientes: `p|uid|rol|chatJid|fechaJornada|shift|messageId`
///   (valor vacío), que existe SOLO mientras el registro está pendiente. Así
///   `pending` recorre claves sin leer ni deserializar el resto.
///
/// Cada componente va con `Uri.encodeComponent`, así que un `|` dentro de un
/// dato no rompe las claves.
///
/// LIMITACIÓN CONOCIDA: se asume una sola pestaña por navegador. Con varias,
/// cada una tiene su propia caché del box y no ve lo que guardó la otra hasta
/// recargar.
class ReviewLocalDatasource {
  static const String boxName = 'image_review_records';

  final LazyBox<String> _box;

  ReviewLocalDatasource._(this._box);

  /// Abre el almacenamiento. Con [path] (tests) usa un directorio; sin él,
  /// `Hive.initFlutter()` (IndexedDB en web).
  static Future<Either<Failure, ReviewLocalDatasource>> open({
    String? path,
  }) async {
    try {
      if (path != null) {
        Hive.init(path);
      } else {
        await Hive.initFlutter();
      }
      final box = await Hive.openLazyBox<String>(boxName);
      return Right(ReviewLocalDatasource._(box));
    } catch (_) {
      return const Left(
        Failure.storage(
          message:
              'No se pudo abrir el almacenamiento local de este dispositivo',
        ),
      );
    }
  }

  /// Cierra el box (los datos quedan guardados). En tests simula una recarga.
  Future<void> close() => _box.close();

  static String _enc(String value) => Uri.encodeComponent(value);

  static String _recordKey(String uid, ReviewRole rol, String messageId) =>
      'r|${_enc(uid)}|${rol.name}|${_enc(messageId)}';

  static String _pendingPrefix(
    String uid,
    ReviewRole rol,
    String chatJid,
    String fechaJornada,
    String shift,
  ) =>
      'p|${_enc(uid)}|${rol.name}|${_enc(chatJid)}|${_enc(fechaJornada)}|'
      '${_enc(shift)}|';

  static String _pendingKey(String uid, ImageReviewRecordModel model) {
    final r = model.record;
    return '${_pendingPrefix(uid, r.rol, r.chatJid, r.fechaJornada, r.shift)}'
        '${_enc(r.messageId)}';
  }

  Failure _unreadable(String messageId) => Failure.storage(
    message: 'No se pudo leer el registro guardado de la imagen $messageId',
  );

  Future<ImageReviewRecordModel?> _read(
    String uid,
    ReviewRole rol,
    String messageId,
  ) async {
    final json = await _box.get(_recordKey(uid, rol, messageId));
    if (json == null) return null;
    return ImageReviewRecordModel.fromMap(
      jsonDecode(json) as Map<String, dynamic>,
    );
  }

  /// `Right(null)` si no hay registro.
  Future<Either<Failure, ImageReviewRecordModel?>> get({
    required String uid,
    required String messageId,
    required ReviewRole rol,
  }) async {
    try {
      return Right(await _read(uid, rol, messageId));
    } catch (_) {
      return Left(_unreadable(messageId));
    }
  }

  /// Crea o reemplaza el registro y mantiene el índice de pendientes.
  Future<Either<Failure, Unit>> put({
    required String uid,
    required ImageReviewRecordModel model,
  }) async {
    final record = model.record;
    try {
      final key = _recordKey(uid, record.rol, record.messageId);
      final json = jsonEncode(model.toMap());
      final newIndex = _pendingKey(uid, model);

      // Si el registro anterior estaba indexado en otra parte (no debería
      // cambiar de chat/jornada, pero no se deja basura), se quita.
      String? staleIndex;
      try {
        final previous = await _read(uid, record.rol, record.messageId);
        if (previous != null) {
          final oldIndex = _pendingKey(uid, previous);
          if (oldIndex != newIndex) staleIndex = oldIndex;
        }
      } catch (_) {
        // Un registro anterior ilegible se sobreescribe.
      }

      if (record.estadoSync == EstadoSync.pendiente) {
        // Índice y registro en una sola escritura.
        await _box.putAll({key: json, newIndex: ''});
      } else {
        // Primero el registro y luego se quita el índice: si se corta en
        // medio, queda un índice viejo que `pending` ignora, nunca un
        // pendiente invisible.
        await _box.put(key, json);
        await _box.delete(newIndex);
      }
      if (staleIndex != null) await _box.delete(staleIndex);
      return const Right(unit);
    } catch (_) {
      return Left(
        Failure.storage(
          message:
              'No se pudo guardar el registro de la imagen '
              '${record.messageId} en este dispositivo',
        ),
      );
    }
  }

  /// Jornadas del chat con pendientes y cuántos tiene cada una. Solo recorre
  /// las claves del índice `p|uid|rol|chatJid|`; no lee ni deserializa ningún
  /// registro (por eso un índice viejo, ver [pending], cuenta hasta que
  /// `pending` lo limpie).
  Future<Either<Failure, List<PendingJornada>>> pendingJornadas({
    required String uid,
    required ReviewRole rol,
    required String chatJid,
  }) async {
    try {
      final prefix = 'p|${_enc(uid)}|${rol.name}|${_enc(chatJid)}|';
      final counts = <(String, String), int>{};
      for (final key in _box.keys) {
        if (key is! String || !key.startsWith(prefix)) continue;
        // fechaJornada|shift|messageId
        final parts = key.substring(prefix.length).split('|');
        if (parts.length != 3) continue;
        final jornada = (
          Uri.decodeComponent(parts[0]),
          Uri.decodeComponent(parts[1]),
        );
        counts[jornada] = (counts[jornada] ?? 0) + 1;
      }
      final jornadas = [
        for (final e in counts.entries)
          PendingJornada(
            fechaJornada: e.key.$1,
            shift: e.key.$2,
            cantidad: e.value,
          ),
      ];
      jornadas.sort((a, b) {
        final byDate = a.fechaJornada.compareTo(b.fechaJornada);
        return byDate != 0 ? byDate : a.shift.compareTo(b.shift);
      });
      return Right(jornadas);
    } catch (_) {
      return const Left(
        Failure.storage(
          message: 'No se pudieron leer los registros pendientes de este chat',
        ),
      );
    }
  }

  /// Borra [indexKey] solo si, releyendo el registro justo ahora, sigue
  /// huérfano. Solo escribe cuando hay orfandad (nunca en una lectura normal).
  /// La relectura evita borrar el índice de un registro que se re-guardó como
  /// pendiente mientras `pending` estaba leyendo (dejaría un pendiente
  /// invisible). Cualquier error se ignora: el índice viejo se ignora otra
  /// vez la próxima vez.
  Future<void> _deleteIfStale(
    String indexKey,
    String uid,
    ReviewRole rol,
    String messageId,
  ) async {
    try {
      final current = await _read(uid, rol, messageId);
      if (current == null ||
          current.record.estadoSync != EstadoSync.pendiente) {
        await _box.delete(indexKey);
      }
    } catch (_) {}
  }

  /// Registros pendientes de la jornada, del más antiguo al más nuevo. Falla
  /// entera (identificando el messageId) si alguno no se puede leer.
  Future<Either<Failure, List<ImageReviewRecordModel>>> pending({
    required String uid,
    required ReviewRole rol,
    required String chatJid,
    required String fechaJornada,
    required String shift,
  }) async {
    final prefix = _pendingPrefix(uid, rol, chatJid, fechaJornada, shift);
    final indexKeys = [
      for (final key in _box.keys)
        if (key is String && key.startsWith(prefix)) key,
    ];

    final models = <ImageReviewRecordModel>[];
    for (final indexKey in indexKeys) {
      final id = Uri.decodeComponent(indexKey.substring(prefix.length));
      try {
        final model = await _read(uid, rol, id);
        // Índice viejo (registro ya sincronizado o inexistente): se ignora
        // y se limpia, para que [pendingJornadas] no lo siga contando.
        if (model == null || model.record.estadoSync != EstadoSync.pendiente) {
          await _deleteIfStale(indexKey, uid, rol, id);
          continue;
        }
        models.add(model);
      } catch (_) {
        return Left(_unreadable(id));
      }
    }
    models.sort((a, b) {
      final byDate = a.record.registradoEn.compareTo(b.record.registradoEn);
      return byDate != 0
          ? byDate
          : a.record.messageId.compareTo(b.record.messageId);
    });
    return Right(models);
  }
}
