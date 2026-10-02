import 'package:whatsapp_monitor_viewer/core/time/bogota_time.dart';

/// Claves de jornada. NO cambian con la tabla nueva: son los ids de
/// `shift_image_counts`, de `reviewShifts` y de la ruta de subida. [night2]
/// solo existe en la tabla vieja (y en sus etiquetas ya guardadas).
enum Shift {
  morning,
  afternoon1,
  afternoon2,
  night1,
  night2,
  holiday,
  outOfShift,
}

// ─── Corte entre la tabla vieja y la nueva ────────────────────────────────

/// Instante (milisegundos UTC) desde el que rige la tabla NUEVA de jornadas.
///
/// null = se usa la tabla vieja en toda la app; se fija el día del
/// despliegue a una medianoche en que no hay jornada abierta.
///
/// Un mensaje se clasifica con la tabla nueva si esto no es null y su
/// `messageTimestamp` es >= este valor; si no, con la vieja. Las etiquetas
/// viejas ya guardadas se siguen reconociendo ([shiftFromLabel]).
const int? newShiftsEffectiveFromMs = null;

/// Si en el instante [instantMs] (ms UTC) rige la tabla nueva. Comparación de
/// enteros, sin zona horaria. [effectiveFromMs] es el corte: por defecto
/// [newShiftsEffectiveFromMs] (solo los tests pasan otro).
bool usesNewShiftTable(
  int instantMs, {
  int? effectiveFromMs = newShiftsEffectiveFromMs,
}) => effectiveFromMs != null && instantMs >= effectiveFromMs;

// ─── Tablas ───────────────────────────────────────────────────────────────

/// Rango de una jornada en minutos desde la medianoche. Los dos extremos son
/// INCLUSIVOS: el fin es el último minuto completo (se trunca al minuto).
typedef ShiftRange = ({int start, int end});

/// Tabla VIEJA, lunes a sábado (hasta el corte). En orden del día.
const _oldWeekdayRanges = <Shift, ShiftRange>{
  Shift.morning: (start: 6 * 60, end: 10 * 60 + 54),
  Shift.afternoon1: (start: 10 * 60 + 55, end: 13 * 60 + 58),
  Shift.afternoon2: (start: 13 * 60 + 59, end: 15 * 60 + 23),
  Shift.night1: (start: 15 * 60 + 24, end: 22 * 60 + 24),
  Shift.night2: (start: 22 * 60 + 25, end: 22 * 60 + 30),
};

/// Tabla VIEJA, domingos.
const ShiftRange _oldSundayRange = (start: 6 * 60, end: 19 * 60 + 20);

/// Tabla NUEVA, lunes a sábado (desde el corte): la de la colección
/// `jornadas` del proyecto `whats-apuestas`. Sin night2. En orden del día:
/// entre dos jornadas seguidas queda un hueco (ver [shiftGapBefore]).
const _newWeekdayRanges = <Shift, ShiftRange>{
  Shift.morning: (start: 5 * 60 + 30, end: 10 * 60 + 51),
  Shift.afternoon1: (start: 10 * 60 + 58, end: 13 * 60 + 55),
  Shift.afternoon2: (start: 14 * 60 + 1, end: 15 * 60 + 20),
  Shift.night1: (start: 15 * 60 + 28, end: 22 * 60 + 15),
};

/// Tabla NUEVA, domingos.
const ShiftRange _newSundayRange = (start: 6 * 60, end: 19 * 60 + 15);

/// Etiquetas de la tabla VIEJA. Se conservan: son las que tienen los mensajes
/// anteriores al corte y los registros ya guardados.
const shiftNames = {
  Shift.morning: 'Jornada Mañana (06:00 – 10:54)',
  Shift.afternoon1: 'Jornada Tarde 1 (10:55 – 13:58)',
  Shift.afternoon2: 'Jornada Tarde 2 (13:59 – 15:23)',
  Shift.night1: 'Jornada Noche (15:24 – 22:24)',
  Shift.night2: 'Jornada Noche (22:25 – 22:30)',
  Shift.holiday: 'Domingo / Festivo (06:00 – 19:20)',
  Shift.outOfShift: 'Fuera de las jornadas',
};

/// Etiquetas de la tabla NUEVA (sin night2).
const newShiftNames = {
  Shift.morning: 'Jornada Mañana (05:30 – 10:51)',
  Shift.afternoon1: 'Jornada Tarde 1 (10:58 – 13:55)',
  Shift.afternoon2: 'Jornada Tarde 2 (14:01 – 15:20)',
  Shift.night1: 'Jornada Noche (15:28 – 22:15)',
  Shift.holiday: 'Domingo / Festivo (06:00 – 19:15)',
  Shift.outOfShift: 'Fuera de las jornadas',
};

/// Etiquetas de VISOR para los huecos de día de la tabla nueva, por la
/// jornada que termina justo antes del hueco. Solo para el visor: para los
/// reportes un hueco es [Shift.outOfShift] ([shiftFromLabel] las traduce
/// así). La madrugada y lo fuera de horario en domingo siguen siendo "Fuera
/// de las jornadas".
const newShiftGapLabels = {
  Shift.morning: 'Fuera de jornada Mañana',
  Shift.afternoon1: 'Fuera de jornada Tarde 1',
  Shift.afternoon2: 'Fuera de jornada Tarde 2',
};

/// Etiquetas de la tabla que rige en [instantMs].
Map<Shift, String> shiftNamesAt(
  int instantMs, {
  int? effectiveFromMs = newShiftsEffectiveFromMs,
}) => usesNewShiftTable(instantMs, effectiveFromMs: effectiveFromMs)
    ? newShiftNames
    : shiftNames;

/// Etiqueta en español (la que trae `Message.shift` /
/// `ImageReviewTarget.shift`) a la clave del enum (la que guarda
/// `reviewShifts`). Reconoce las etiquetas de las DOS tablas (la misma clave
/// para la vieja y la nueva); las de huecos ([newShiftGapLabels]) dan
/// [Shift.outOfShift], porque no cuentan para reportes. `null` si no coincide
/// con ninguna — no debería pasar salvo un dato corrupto; quien llame decide
/// qué hacer (tratarlo como "sin coincidencia").
Shift? shiftFromLabel(String label) {
  for (final names in const [shiftNames, newShiftNames]) {
    for (final entry in names.entries) {
      if (entry.value == label) return entry.key;
    }
  }
  if (newShiftGapLabels.containsValue(label)) return Shift.outOfShift;
  return null;
}

// ─── Clasificación ────────────────────────────────────────────────────────

bool _inRange(int minutes, ShiftRange range) =>
    minutes >= range.start && minutes <= range.end;

/// Jornada de [date] para REPORTES (formulario, subida, reconciliación,
/// pendientes): lo que cae fuera de todos los rangos — también un hueco de la
/// tabla nueva — es [Shift.outOfShift]. Se trunca al minuto y el fin es
/// inclusivo. La tabla se elige con [usesNewShiftTable] sobre el instante de
/// [date]; la hora de pared es la de [date], tal cual llega.
Shift getCurrentShift(
  DateTime date, {
  int? effectiveFromMs = newShiftsEffectiveFromMs,
}) {
  final newTable = usesNewShiftTable(
    date.millisecondsSinceEpoch,
    effectiveFromMs: effectiveFromMs,
  );
  final minutes = date.hour * 60 + date.minute;

  // Domingos / festivos (solo se detectan domingos).
  if (date.weekday == DateTime.sunday) {
    final range = newTable ? _newSundayRange : _oldSundayRange;
    return _inRange(minutes, range) ? Shift.holiday : Shift.outOfShift;
  }

  // Lunes a sábado.
  final ranges = newTable ? _newWeekdayRanges : _oldWeekdayRanges;
  for (final entry in ranges.entries) {
    if (_inRange(minutes, entry.value)) return entry.key;
  }
  return Shift.outOfShift;
}

/// Si [date] cae en un hueco de día de la tabla nueva, la jornada que termina
/// justo antes; si no, null. La tabla vieja no tiene huecos, y la madrugada y
/// los domingos no cuentan como hueco. Solo para el visor.
Shift? shiftGapBefore(
  DateTime date, {
  int? effectiveFromMs = newShiftsEffectiveFromMs,
}) {
  if (!usesNewShiftTable(
    date.millisecondsSinceEpoch,
    effectiveFromMs: effectiveFromMs,
  )) {
    return null;
  }
  if (date.weekday == DateTime.sunday) return null;

  final minutes = date.hour * 60 + date.minute;
  final entries = _newWeekdayRanges.entries.toList(growable: false);
  for (var i = 0; i + 1 < entries.length; i++) {
    if (minutes > entries[i].value.end &&
        minutes < entries[i + 1].value.start) {
      return entries[i].key;
    }
  }
  return null;
}

/// Etiqueta de [date] para el VISOR: la de su jornada en la tabla que rige,
/// o, en un hueco de día de la tabla nueva, "Fuera de jornada X" (se agrupa
/// junto a esa jornada). Con la tabla vieja es exactamente
/// `shiftNames[getCurrentShift(date)]`.
String shiftViewerLabel(
  DateTime date, {
  int? effectiveFromMs = newShiftsEffectiveFromMs,
}) {
  final gap = shiftGapBefore(date, effectiveFromMs: effectiveFromMs);
  if (gap != null) return newShiftGapLabels[gap]!;
  final shift = getCurrentShift(date, effectiveFromMs: effectiveFromMs);
  return shiftNamesAt(
    date.millisecondsSinceEpoch,
    effectiveFromMs: effectiveFromMs,
  )[shift]!;
}

// ─── Fin de jornada ───────────────────────────────────────────────────────

/// Último minuto INCLUSIVO de cada jornada asignable de la tabla VIEJA, en
/// minutos desde la medianoche. Debe coincidir con los límites de
/// [getCurrentShift] (lo verifica `shifts_end_test.dart`). [Shift.outOfShift]
/// no tiene fin.
const shiftLastMinute = <Shift, int>{
  Shift.morning: 10 * 60 + 54,
  Shift.afternoon1: 13 * 60 + 58,
  Shift.afternoon2: 15 * 60 + 23,
  Shift.night1: 22 * 60 + 24,
  Shift.night2: 22 * 60 + 30,
  Shift.holiday: 19 * 60 + 20,
};

/// Lo mismo para la tabla NUEVA (sin night2).
const newShiftLastMinute = <Shift, int>{
  Shift.morning: 10 * 60 + 51,
  Shift.afternoon1: 13 * 60 + 55,
  Shift.afternoon2: 15 * 60 + 20,
  Shift.night1: 22 * 60 + 15,
  Shift.holiday: 19 * 60 + 15,
};

final _fechaJornadaFormat = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Si la jornada [shift] del día [fechaJornada] (`yyyy-MM-dd`) ya terminó a la
/// hora [now]: desde el minuto siguiente a su último minuto inclusivo (con la
/// tabla vieja la mañana termina a las 10:55:00), sin margen.
///
/// La fecha de la jornada y [now] se comparan en hora de Bogotá
/// ([bogotaWallClock]), no en la zona del dispositivo. Por eso un día anterior
/// a hoy siempre terminó y un día futuro nunca. `false` para
/// [Shift.outOfShift], para una jornada que no existe en la tabla de ese día
/// (night2 con la tabla nueva) y para una fecha con formato inválido.
///
/// La tabla se elige por el DÍA de la jornada contra el corte
/// ([newShiftsEffectiveFromMs], llevado a hora de Bogotá con
/// [bogotaWallClock]): el corte cae a una medianoche sin jornada abierta, así
/// que un día usa una sola tabla.
bool jornadaTerminada(
  String fechaJornada,
  Shift shift,
  DateTime now, {
  int? effectiveFromMs = newShiftsEffectiveFromMs,
}) {
  final match = _fechaJornadaFormat.firstMatch(fechaJornada);
  if (match == null) return false;
  final day = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );

  final newTable =
      effectiveFromMs != null &&
      !day.isBefore(
        bogotaWallClock(
          DateTime.fromMillisecondsSinceEpoch(effectiveFromMs, isUtc: true),
        ),
      );
  final lastMinute = (newTable ? newShiftLastMinute : shiftLastMinute)[shift];
  if (lastMinute == null) return false;

  final endOfShift = day.add(Duration(minutes: lastMinute + 1));
  return !bogotaWallClock(now).isBefore(endOfShift);
}
