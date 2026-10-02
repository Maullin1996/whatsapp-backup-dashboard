import 'package:whatsapp_monitor_viewer/core/time/bogota_time.dart';

/// Claves de jornada. NO cambian: son los ids de `shift_image_counts`, de
/// `reviewShifts` y de la ruta de subida. [night2] se conserva solo como
/// valor (lo usan el bot, `reviewShifts` y etiquetas ya guardadas): ninguna
/// hora cae en ella ([getCurrentShift] nunca la devuelve).
enum Shift {
  morning,
  afternoon1,
  afternoon2,
  night1,
  night2,
  holiday,
  outOfShift,
}

// ─── Tabla ────────────────────────────────────────────────────────────────

/// Rango de una jornada en minutos desde la medianoche. Los dos extremos son
/// INCLUSIVOS: el fin es el último minuto completo (se trunca al minuto).
typedef ShiftRange = ({int start, int end});

/// Lunes a sábado: la tabla de la colección `jornadas` del proyecto
/// `whats-apuestas`, única en toda la app. Sin night2. En orden del día:
/// entre dos jornadas seguidas queda un hueco (ver [shiftGapBefore]).
const _weekdayRanges = <Shift, ShiftRange>{
  Shift.morning: (start: 5 * 60 + 30, end: 10 * 60 + 51),
  Shift.afternoon1: (start: 10 * 60 + 58, end: 13 * 60 + 55),
  Shift.afternoon2: (start: 14 * 60 + 1, end: 15 * 60 + 20),
  Shift.night1: (start: 15 * 60 + 28, end: 22 * 60 + 15),
};

/// Domingos (no se detectan festivos).
const ShiftRange _sundayRange = (start: 6 * 60, end: 19 * 60 + 15);

/// Etiquetas de la tabla (sin night2).
const shiftNames = {
  Shift.morning: 'Jornada Mañana (05:30 – 10:51)',
  Shift.afternoon1: 'Jornada Tarde 1 (10:58 – 13:55)',
  Shift.afternoon2: 'Jornada Tarde 2 (14:01 – 15:20)',
  Shift.night1: 'Jornada Noche (15:28 – 22:15)',
  Shift.holiday: 'Domingo / Festivo (06:00 – 19:15)',
  Shift.outOfShift: 'Fuera de las jornadas',
};

/// Etiquetas de la tabla VIEJA, ya retirada. Solo para reconocer registros
/// guardados y documentos subidos con ellas ([shiftFromLabel]) y como
/// respaldo de la etiqueta de night2 (`shiftNames[s] ?? legacyShiftNames[s]`).
/// Ningún mensaje nuevo recibe una de estas etiquetas.
const legacyShiftNames = {
  Shift.morning: 'Jornada Mañana (06:00 – 10:54)',
  Shift.afternoon1: 'Jornada Tarde 1 (10:55 – 13:58)',
  Shift.afternoon2: 'Jornada Tarde 2 (13:59 – 15:23)',
  Shift.night1: 'Jornada Noche (15:24 – 22:24)',
  Shift.night2: 'Jornada Noche (22:25 – 22:30)',
  Shift.holiday: 'Domingo / Festivo (06:00 – 19:20)',
  Shift.outOfShift: 'Fuera de las jornadas',
};

/// Etiquetas de VISOR para los huecos de día, por la jornada que termina
/// justo antes del hueco. Solo para el visor: para los reportes un hueco es
/// [Shift.outOfShift] ([shiftFromLabel] las traduce así). La madrugada y lo
/// fuera de horario en domingo siguen siendo "Fuera de las jornadas".
const shiftGapLabels = {
  Shift.morning: 'Fuera de jornada Mañana',
  Shift.afternoon1: 'Fuera de jornada Tarde 1',
  Shift.afternoon2: 'Fuera de jornada Tarde 2',
};

/// Etiqueta en español (la que trae `Message.shift` /
/// `ImageReviewTarget.shift`) a la clave del enum (la que guarda
/// `reviewShifts`). Reconoce las etiquetas actuales y las viejas
/// ([legacyShiftNames], la misma clave); las de huecos ([shiftGapLabels]) dan
/// [Shift.outOfShift], porque no cuentan para reportes. `null` si no coincide
/// con ninguna — no debería pasar salvo un dato corrupto; quien llame decide
/// qué hacer (tratarlo como "sin coincidencia").
Shift? shiftFromLabel(String label) {
  for (final names in const [shiftNames, legacyShiftNames]) {
    for (final entry in names.entries) {
      if (entry.value == label) return entry.key;
    }
  }
  if (shiftGapLabels.containsValue(label)) return Shift.outOfShift;
  return null;
}

// ─── Clasificación ────────────────────────────────────────────────────────

bool _inRange(int minutes, ShiftRange range) =>
    minutes >= range.start && minutes <= range.end;

/// Jornada de [date] para REPORTES (formulario, subida, reconciliación,
/// pendientes): lo que cae fuera de todos los rangos — también un hueco — es
/// [Shift.outOfShift]. Se trunca al minuto y el fin es inclusivo. La hora de
/// pared es la de [date], tal cual llega. Nunca devuelve [Shift.night2].
Shift getCurrentShift(DateTime date) {
  final minutes = date.hour * 60 + date.minute;

  // Domingos / festivos (solo se detectan domingos).
  if (date.weekday == DateTime.sunday) {
    return _inRange(minutes, _sundayRange) ? Shift.holiday : Shift.outOfShift;
  }

  // Lunes a sábado.
  for (final entry in _weekdayRanges.entries) {
    if (_inRange(minutes, entry.value)) return entry.key;
  }
  return Shift.outOfShift;
}

/// Si [date] cae en un hueco de día, la jornada que termina justo antes; si
/// no, null. La madrugada y los domingos no cuentan como hueco. Solo para el
/// visor.
Shift? shiftGapBefore(DateTime date) {
  if (date.weekday == DateTime.sunday) return null;

  final minutes = date.hour * 60 + date.minute;
  final entries = _weekdayRanges.entries.toList(growable: false);
  for (var i = 0; i + 1 < entries.length; i++) {
    if (minutes > entries[i].value.end &&
        minutes < entries[i + 1].value.start) {
      return entries[i].key;
    }
  }
  return null;
}

/// Etiqueta de [date] para el VISOR: la de su jornada o, en un hueco de día,
/// "Fuera de jornada X" (se agrupa junto a esa jornada).
String shiftViewerLabel(DateTime date) {
  final gap = shiftGapBefore(date);
  if (gap != null) return shiftGapLabels[gap]!;
  return shiftNames[getCurrentShift(date)]!;
}

// ─── Fin de jornada ───────────────────────────────────────────────────────

/// Último minuto INCLUSIVO de cada jornada, en minutos desde la medianoche.
/// Debe coincidir con los límites de [getCurrentShift] (lo verifica
/// `shifts_end_test.dart`). Sin night2 ni [Shift.outOfShift].
const shiftLastMinute = <Shift, int>{
  Shift.morning: 10 * 60 + 51,
  Shift.afternoon1: 13 * 60 + 55,
  Shift.afternoon2: 15 * 60 + 20,
  Shift.night1: 22 * 60 + 15,
  Shift.holiday: 19 * 60 + 15,
};

final _fechaJornadaFormat = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Si la jornada [shift] del día [fechaJornada] (`yyyy-MM-dd`) ya terminó a la
/// hora [now]: desde el minuto siguiente a su último minuto inclusivo (la
/// mañana termina a las 10:52:00), sin margen.
///
/// La fecha de la jornada y [now] se comparan en hora de Bogotá
/// ([bogotaWallClock]), no en la zona del dispositivo. Por eso un día anterior
/// a hoy siempre terminó y un día futuro nunca. `false` para
/// [Shift.outOfShift], para [Shift.night2] (no está en la tabla) y para una
/// fecha con formato inválido.
bool jornadaTerminada(String fechaJornada, Shift shift, DateTime now) {
  final match = _fechaJornadaFormat.firstMatch(fechaJornada);
  if (match == null) return false;
  final day = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );

  final lastMinute = shiftLastMinute[shift];
  if (lastMinute == null) return false;

  final endOfShift = day.add(Duration(minutes: lastMinute + 1));
  return !bogotaWallClock(now).isBefore(endOfShift);
}
