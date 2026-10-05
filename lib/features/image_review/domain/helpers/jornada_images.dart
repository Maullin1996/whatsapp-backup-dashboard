import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';

/// [message] es una imagen de la jornada [shift] del día [fechaJornada]
/// (`yyyy-MM-dd`). Usa lo que ya calcula la app: la etiqueta de jornada de
/// `toDomain` (traducida con `shiftFromLabel`) y `fechaJornadaDe`. Una imagen
/// en un hueco entre jornadas ("Fuera de jornada X") o fuera de las jornadas
/// da `outOfShift` y nunca entra, igual que hoy no abre el formulario.
bool isImageOfJornada(Message message, String fechaJornada, Shift shift) =>
    message.isImage &&
    shift != Shift.outOfShift &&
    shiftFromLabel(message.shift) == shift &&
    fechaJornadaDe(message.messageTimestamp) == fechaJornada;

/// Orden de la pantalla de llenado: de la PRIMERA a la ÚLTIMA (al revés del
/// visor del chat). Empates de hora: `shiftImageIndex` y luego el id, como el
/// orden del chat pero ascendente.
int compareOldestFirst(Message a, Message b) {
  final byTime = a.messageTimestamp.compareTo(b.messageTimestamp);
  if (byTime != 0) return byTime;
  final aIdx = a.shiftImageIndex;
  final bIdx = b.shiftImageIndex;
  if (aIdx != null && bIdx != null && aIdx != bIdx) return aIdx.compareTo(bIdx);
  return a.id.compareTo(b.id);
}
