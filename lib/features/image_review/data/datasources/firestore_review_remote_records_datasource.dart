import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_remote_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_raw_document.dart';

/// Lee los documentos de la colección [collectionPath] cuyo campo `rol` es
/// [rol].
typedef RemoteRecordsReader =
    Future<List<RawDocument>> Function(String collectionPath, String rol);

/// Tiempo máximo para leer los registros de una jornada. Si se pasa, es un
/// `Left` (la pantalla muestra "Reintentar"), no una espera sin fin.
const Duration reviewRemoteReadTimeout = Duration(seconds: 15);

/// [ReviewRemoteRecordsDatasource] con Firestore: una consulta sobre
/// `image_reviews/{chatJid}/jornadas/{fechaJornada}_{shiftKey}/registros` con
/// `rol == <rol>`, forzada al servidor (`Source.server`). Nunca un `get` por
/// id: la regla niega leer un registro que no existe. Nunca lanza.
class FirestoreReviewRemoteRecordsDatasource
    implements ReviewRemoteRecordsDatasource {
  /// Lectura real contra [firestore].
  FirestoreReviewRemoteRecordsDatasource(
    FirebaseFirestore firestore, {
    Duration timeout = reviewRemoteReadTimeout,
  }) : this.withReader((collectionPath, rol) async {
         final snapshot = await firestore
             .collection(collectionPath)
             .where('rol', isEqualTo: rol)
             .get(const GetOptions(source: Source.server));
         return [for (final d in snapshot.docs) (id: d.id, data: d.data())];
       }, timeout: timeout);

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreReviewRemoteRecordsDatasource.withReader(
    this._read, {
    this.timeout = reviewRemoteReadTimeout,
  });

  final RemoteRecordsReader _read;
  final Duration timeout;

  @override
  Future<Either<Failure, List<ImageReviewRecordModel>>> fetchJornada({
    required String chatJid,
    required String fechaJornada,
    required Shift shift,
    required ReviewRole rol,
  }) async {
    final segments = [
      ImageReviewRecordModel.uploadRootCollection,
      chatJid,
      ImageReviewRecordModel.uploadJornadasCollection,
      '${fechaJornada}_${shift.name}',
      ImageReviewRecordModel.uploadRegistrosCollection,
    ];
    if (shift == Shift.outOfShift ||
        segments.any((s) => s.isEmpty || s.contains('/'))) {
      return Left(
        Failure.unknown(
          message: 'Ruta de lectura inválida: ${segments.join(' | ')}',
        ),
      );
    }
    final path = segments.join('/');

    final List<RawDocument> docs;
    try {
      docs = await _read(path, rol.name).timeout(timeout);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } on TimeoutException {
      return Left(
        Failure.unknown(
          message:
              'No se pudieron leer a tiempo los registros subidos de esta '
              'jornada.',
        ),
      );
    } catch (_) {
      return Left(
        Failure.unknown(
          message: 'Error inesperado al leer los registros subidos ($path).',
        ),
      );
    }

    final models = <ImageReviewRecordModel>[];
    for (final doc in docs) {
      final model = _parse(doc);
      // Ilegible (falta un campo, otro tipo, fecha ilegible): se omite y esa
      // imagen cuenta como sin formulario. Queda en el log con su ruta.
      if (model == null) {
        debugPrint(
          '[REVISION] registro subido ilegible, omitido: $path/${doc.id}',
        );
        continue;
      }
      final r = model.record;
      // Legible pero de otra jornada, otro rol o con otro id: error duro.
      // Guardarlo en local lo dejaría bajo otra imagen o jornada.
      if (r.rol != rol ||
          r.chatJid != chatJid ||
          r.fechaJornada != fechaJornada ||
          doc.data['shiftKey'] != shift.name ||
          doc.id != '${r.messageId}_${rol.name}') {
        return Left(
          Failure.unknown(
            message:
                'El registro subido ${doc.id} tiene un formato inesperado '
                '($path).',
          ),
        );
      }
      models.add(model);
    }
    return Right(models);
  }

  /// El documento subido es lo persistido sin `v` ni `estadoSync` (ver
  /// `toUploadDocument`): se agregan y se reutiliza `fromMap`, que lanza si
  /// falta un campo o tiene otro tipo. null si no se puede convertir.
  static ImageReviewRecordModel? _parse(RawDocument doc) {
    try {
      return ImageReviewRecordModel.fromMap({
        ...doc.data,
        'v': ImageReviewRecordModel.currentSchemaVersion,
        'estadoSync': EstadoSync.sincronizado.name,
      });
    } catch (_) {
      return null;
    }
  }
}
