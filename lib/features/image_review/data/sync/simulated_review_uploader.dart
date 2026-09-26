import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';

/// Subida SIMULADA: no toca Firestore, solo imprime en consola (`debugPrint`)
/// lo que se subiría: colección, id del documento y datos. Nunca falla.
///
/// La conexión real es otra implementación de [ReviewUploader]; no se activa
/// sin autorización explícita.
class SimulatedReviewUploader implements ReviewUploader {
  const SimulatedReviewUploader();

  static const _encoder = JsonEncoder.withIndent('  ');

  @override
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record) async {
    final model = ImageReviewRecordModel(record);
    debugPrint(
      '[SUBIDA SIMULADA] '
      '${ImageReviewRecordModel.uploadCollection}/${model.uploadDocumentId}\n'
      '${_encoder.convert(model.toUploadMap())}',
    );
    return const Right(unit);
  }
}
