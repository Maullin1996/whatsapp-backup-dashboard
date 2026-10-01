import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Un documento leído de Firestore, reducido a su id y sus datos: así las
/// lecturas se pueden reemplazar por una función falsa en los tests.
typedef RawDocument = ({String id, Map<String, dynamic> data});

/// Documento con un campo faltante o de otro tipo. Se lanza SOLO dentro de
/// los parsers de este directorio y se convierte en `Left` antes de salir del
/// datasource (los datasources nunca lanzan).
class UnexpectedDocumentFormat implements Exception {
  final String message;

  const UnexpectedDocumentFormat(this.message);
}

/// Lee [field] de [doc] exigiendo el tipo [T]; si falta o es de otro tipo,
/// lanza [UnexpectedDocumentFormat] con [what] y el id del documento.
T requireField<T>(RawDocument doc, String field, String what) {
  final value = doc.data[field];
  if (value is T) return value;
  throw UnexpectedDocumentFormat(
    '$what ${doc.id} tiene un formato inesperado: el campo "$field" '
    '${value == null ? 'falta' : 'no es del tipo esperado'}.',
  );
}

/// La jornada de [key] (nombre del enum [Shift]); lanza
/// [UnexpectedDocumentFormat] si es desconocida o [Shift.outOfShift].
Shift requireShiftKey(RawDocument doc, String key, String what) {
  final shift = Shift.values.asNameMap()[key];
  if (shift == null || shift == Shift.outOfShift) {
    throw UnexpectedDocumentFormat(
      '$what ${doc.id} tiene una jornada inválida ("$key").',
    );
  }
  return shift;
}
