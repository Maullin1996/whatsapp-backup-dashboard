import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

final _prefix = RegExp(r'^Jornada\s+');
final _range = RegExp(r'\s*\((\d{2}:\d{2}).*\)$');

String _base(String label) =>
    label.replaceFirst(_prefix, '').replaceFirst(_range, '');

/// Nombre corto de una jornada a partir del texto largo que guarda el registro
/// ("Jornada Mañana (06:00 – 10:54)" -> "Mañana").
///
/// Si dos jornadas darían el mismo nombre corto (las dos "Noche"), se agrega
/// la hora de inicio para distinguirlas ("Noche (15:24)"). Un texto que no
/// sigue el formato se devuelve tal cual.
String shortShiftName(String label) {
  final base = _base(label);
  final collides =
      shiftNames.values.where((other) => _base(other) == base).length > 1;
  if (!collides) return base;
  final start = _range.firstMatch(label)?.group(1);
  return start == null ? base : '$base ($start)';
}

/// Fecha de una jornada (`yyyy-MM-dd`) como "dd/MM/yyyy", o `null` si es hoy
/// (a las etiquetas solo se les agrega la fecha cuando no es hoy).
String? jornadaDateLabel(String fechaJornada, {DateTime? now}) {
  final today = fechaJornadaDe((now ?? DateTime.now()).millisecondsSinceEpoch);
  if (fechaJornada == today) return null;
  final parts = fechaJornada.split('-');
  if (parts.length != 3) return fechaJornada;
  return '${parts[2]}/${parts[1]}/${parts[0]}';
}
