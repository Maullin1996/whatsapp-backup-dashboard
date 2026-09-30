import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Un registro listo para subir: [pathSegments] alterna colección / documento
/// (ver [ImageReviewRecordModel.toUploadDocument]).
class ReviewUploadDocument {
  final List<String> pathSegments;
  final Map<String, dynamic> data;

  const ReviewUploadDocument({required this.pathSegments, required this.data});

  String get path => pathSegments.join('/');
}

/// Forma persistida de un [ImageReviewRecord]: un `Map` de tipos primitivos
/// (que se guarda como JSON) con una versión de esquema para poder migrar.
///
/// Es propio de `data/`: las entidades de domain no llevan anotaciones de la
/// librería de almacenamiento.
class ImageReviewRecordModel {
  /// Versión de esquema que escribe esta app. Al cambiar el formato: subir
  /// este número y agregar el paso correspondiente en [migrate].
  static const int currentSchemaVersion = 1;

  final ImageReviewRecord record;

  const ImageReviewRecordModel(this.record);

  Map<String, dynamic> toMap() => {
    'v': currentSchemaVersion,
    'messageId': record.messageId,
    'chatJid': record.chatJid,
    'shift': record.shift,
    'rol': record.rol.name,
    'storagePath': record.storagePath,
    'fechaJornada': record.fechaJornada,
    // Tal cual (ms); null solo en registros guardados antes de este campo.
    'messageTimestamp': record.messageTimestamp,
    'comprobantes': [
      for (final c in record.form.comprobantes)
        {'codigo': c.codigo, 'numeros': c.numeros, 'total': c.total},
    ],
    'anotaciones': record.form.anotaciones,
    // UTC en ISO-8601; al leer se devuelve en hora local.
    'registradoEn': record.registradoEn.toUtc().toIso8601String(),
    'registradoPor': record.registradoPor,
    'editado': record.editado,
    'estadoSync': record.estadoSync.name,
  };

  // Ruta de subida (nombres PROVISIONALES, solo aquí):
  // image_reviews/{chatJid}/jornadas/{fechaJornada}_{shiftKey}/registros/{messageId}_{rol}
  static const String uploadRootCollection = 'image_reviews';
  static const String uploadJornadasCollection = 'jornadas';
  static const String uploadRegistrosCollection = 'registros';

  /// Documento a subir: la ruta por grupo -> jornada -> registro y los datos.
  ///
  /// `shiftKey` es el nombre del enum [Shift] de la etiqueta guardada en el
  /// registro. `Left` si la etiqueta no es de una jornada asignable
  /// (desconocida o [Shift.outOfShift]), si el registro no tiene
  /// `messageTimestamp` (guardado antes de ese campo) o si algún segmento de
  /// la ruta queda vacío o con "/". El id lleva el rol: Revisor y Sumador de
  /// la misma imagen comparten jornada y no se pisan.
  Either<Failure, ReviewUploadDocument> toUploadDocument() {
    final shift = shiftFromLabel(record.shift);
    if (shift == null || shift == Shift.outOfShift) {
      return Left(
        Failure.unknown(
          message:
              'La imagen no pertenece a una jornada asignable '
              '("${record.shift}"): no se puede subir.',
        ),
      );
    }
    if (record.messageTimestamp == null) {
      return Left(
        Failure.unknown(
          message:
              'El registro de la imagen ${record.messageId} es anterior a '
              'este cambio y no se puede subir: guárdalo de nuevo desde el '
              'visor.',
        ),
      );
    }

    final segments = [
      uploadRootCollection,
      record.chatJid,
      uploadJornadasCollection,
      '${record.fechaJornada}_${shift.name}',
      uploadRegistrosCollection,
      '${record.messageId}_${record.rol.name}',
    ];
    if (segments.any((s) => s.isEmpty || s.contains('/'))) {
      return Left(
        Failure.unknown(
          message: 'Ruta de subida inválida: ${segments.join(' | ')}',
        ),
      );
    }

    // Lo persistido, sin lo que es solo local (versión de esquema y estado de
    // sincronización), más la jornada como nombre del enum.
    final data = toMap()
      ..remove('v')
      ..remove('estadoSync')
      ..['shiftKey'] = shift.name;
    return Right(ReviewUploadDocument(pathSegments: segments, data: data));
  }

  /// Lee un mapa persistido (de cualquier versión conocida). Lanza si le
  /// falta algo, tiene un tipo inesperado o es de una versión más nueva que
  /// la que esta app entiende; quien lo llama lo convierte en `Failure`.
  factory ImageReviewRecordModel.fromMap(Map<String, dynamic> raw) {
    final map = migrate(raw);
    final comprobantes = (map['comprobantes'] as List)
        .map((c) => c as Map)
        .map(
          (c) => Comprobante(
            codigo: c['codigo'] as String,
            numeros: (c['numeros'] as List).cast<String>().toList(),
            total: c['total'] as int,
          ),
        )
        .toList();

    return ImageReviewRecordModel(
      ImageReviewRecord(
        messageId: map['messageId'] as String,
        chatJid: map['chatJid'] as String,
        shift: map['shift'] as String,
        rol: ReviewRole.values.byName(map['rol'] as String),
        storagePath: map['storagePath'] as String,
        fechaJornada: map['fechaJornada'] as String,
        // Opcional sin subir el esquema: ausente (registro de antes) -> null;
        // presente con otro tipo -> falla como los demás campos.
        messageTimestamp: map['messageTimestamp'] as int?,
        form: ImageReviewForm(
          comprobantes: comprobantes,
          anotaciones: map['anotaciones'] as String?,
        ),
        registradoEn: DateTime.parse(map['registradoEn'] as String).toLocal(),
        registradoPor: map['registradoPor'] as String,
        editado: map['editado'] as bool,
        estadoSync: EstadoSync.values.byName(map['estadoSync'] as String),
      ),
    );
  }

  /// Lleva un mapa persistido a [currentSchemaVersion]. Hoy solo existe la
  /// versión 1; cuando cambie el formato se encadenan aquí los pasos
  /// (`if (v < 2) m = _v1ToV2(m);`, etc.).
  static Map<String, dynamic> migrate(Map<String, dynamic> map) {
    final v = map['v'];
    if (v is! int) {
      throw const FormatException('falta la versión de esquema');
    }
    if (v > currentSchemaVersion) {
      throw FormatException(
        'esquema v$v más nuevo que el soportado (v$currentSchemaVersion)',
      );
    }
    return map;
  }
}
