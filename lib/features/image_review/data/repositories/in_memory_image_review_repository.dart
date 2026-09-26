import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/pending_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/image_review_repository.dart';

/// Implementación en memoria (se pierde al cerrar la app). Ya no es la de
/// producción (`LocalImageReviewRepository`): se mantiene para los tests que
/// no necesitan almacenamiento real.
class InMemoryImageReviewRepository implements ImageReviewRepository {
  final Map<({String messageId, ReviewRole rol}), ImageReviewRecord> _records =
      {};

  @override
  Future<Either<Failure, ImageReviewRecord?>> getByMessageId(
    String messageId,
    ReviewRole rol,
  ) async => Right(_records[(messageId: messageId, rol: rol)]);

  @override
  Future<Either<Failure, Unit>> save(ImageReviewRecord record) async {
    _records[(messageId: record.messageId, rol: record.rol)] = record;
    return const Right(unit);
  }

  @override
  Future<Either<Failure, List<ImageReviewRecord>>> getPending({
    required String chatJid,
    required String fechaJornada,
    required String shift,
    required ReviewRole rol,
  }) async {
    final pending =
        _records.values
            .where(
              (r) =>
                  r.rol == rol &&
                  r.chatJid == chatJid &&
                  r.fechaJornada == fechaJornada &&
                  r.shift == shift &&
                  r.estadoSync == EstadoSync.pendiente,
            )
            .toList()
          ..sort((a, b) {
            final byDate = a.registradoEn.compareTo(b.registradoEn);
            return byDate != 0 ? byDate : a.messageId.compareTo(b.messageId);
          });
    return Right(pending);
  }

  @override
  Future<Either<Failure, List<PendingJornada>>> getPendingJornadas({
    required String chatJid,
    required ReviewRole rol,
  }) async {
    final counts = <(String, String), int>{};
    for (final r in _records.values) {
      if (r.rol != rol ||
          r.chatJid != chatJid ||
          r.estadoSync != EstadoSync.pendiente) {
        continue;
      }
      final key = (r.fechaJornada, r.shift);
      counts[key] = (counts[key] ?? 0) + 1;
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
  }
}
