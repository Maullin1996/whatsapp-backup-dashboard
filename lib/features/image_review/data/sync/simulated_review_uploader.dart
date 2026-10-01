import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';

/// Subida SIMULADA: no toca Firestore, solo imprime en consola (`debugPrint`)
/// lo que se subiría: la ruta completa del documento y sus datos. Solo falla
/// (sin imprimir nada) si el registro no tiene una ruta válida (ver
/// [ImageReviewRecordModel.toUploadDocument]).
///
/// No cableado en producción; solo tests y referencia; candidato a borrar.
/// La subida real es `FirestoreReviewUploader` (ver `reviewUploaderProvider`).
class SimulatedReviewUploader implements ReviewUploader {
  const SimulatedReviewUploader();

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record) async {
    return ImageReviewRecordModel(record).toUploadDocument().map((document) {
      debugPrint(
        '[SUBIDA SIMULADA] ${document.path}\n'
        '${_encoder.convert(document.data)}',
      );
      return unit;
    });
  }
}
