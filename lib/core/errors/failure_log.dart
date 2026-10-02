import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';

/// Línea de log de una lectura fallida (`[<tag>] falló (<tipo>)...`). Los
/// errores de Firestore y de permisos llevan su texto completo (si falta un
/// índice, trae el enlace para crearlo); los demás solo el tipo, porque su
/// texto puede nombrar un documento (por ejemplo `messageId_rol`). Nunca
/// imprime documentos ni datos.
String failureLogLine(String tag, Failure failure) => failure.map(
  firestore: (f) => '[$tag] falló (firestore): ${f.message}',
  unauthorized: (f) => '[$tag] falló (unauthorized): ${f.message}',
  storage: (_) => '[$tag] falló (storage)',
  unknown: (_) => '[$tag] falló (unknown)',
);
