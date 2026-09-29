import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

abstract class ReviewShiftsDatasource {
  Future<List<ReviewShift>> fetchReviewShifts(String uid);
}

/// Convierte el `reviewShifts` de un documento `users/{uid}` (lista de
/// `{chatJid, shift}`, o ausente) en la lista tipada. Mismo manejo defensivo
/// por entrada que `parseReviewShifts` del lado de admin
/// (`admin_datasource_impl.dart`): una entrada corrupta se descarta con
/// `debugPrint` sin afectar a las demás.
List<ReviewShift> parseReviewShiftsField(Object? raw) {
  if (raw == null) return const [];
  final list = raw as List<dynamic>;
  final result = <ReviewShift>[];
  for (final entry in list) {
    try {
      final map = entry as Map<Object?, Object?>;
      result.add(
        ReviewShift(
          chatJid: map['chatJid'] as String,
          shift: Shift.values.byName(map['shift'] as String),
        ),
      );
    } catch (e) {
      debugPrint('Entrada de reviewShifts inválida ($entry): se descarta. $e');
    }
  }
  return result;
}

/// Lee `users/{uid}.reviewShifts` con el mismo patrón de lectura única (sin
/// `.snapshots()`) que `ChatsFirestoreDatasource.fetchAllowedGroups`: una
/// jornada revocada se refleja la próxima vez que se reconstruya el
/// provider (recarga de sesión), no al instante.
class ReviewShiftsFirestoreDatasource implements ReviewShiftsDatasource {
  final FirebaseFirestore _db;

  const ReviewShiftsFirestoreDatasource(this._db);

  @override
  Future<List<ReviewShift>> fetchReviewShifts(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return const [];
    return parseReviewShiftsField(doc.data()?['reviewShifts']);
  }
}
