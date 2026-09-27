enum Shift {
  morning,
  afternoon1,
  afternoon2,
  night1,
  night2,
  holiday,
  outOfShift,
}

const shiftNames = {
  Shift.morning: 'Jornada Mañana (06:00 – 10:54)',
  Shift.afternoon1: 'Jornada Tarde 1 (10:55 – 13:58)',
  Shift.afternoon2: 'Jornada Tarde 2 (13:59 – 15:23)',
  Shift.night1: 'Jornada Noche (15:24 – 22:24)',
  Shift.night2: 'Jornada Noche (22:25 – 22:30)',
  Shift.holiday: 'Domingo / Festivo (06:00 – 19:20)',
  Shift.outOfShift: 'Fuera de las jornadas',
};

/// Inverso de [shiftNames]: la etiqueta en español (la que trae
/// `Message.shift` / `ImageReviewTarget.shift`) al valor del enum (el que
/// guarda `reviewShifts`). `null` si la etiqueta no coincide con ninguna —
/// no debería pasar salvo un dato corrupto o una etiqueta desactualizada;
/// quien llame decide qué hacer (tratarlo como "sin coincidencia").
Shift? shiftFromLabel(String label) {
  for (final entry in shiftNames.entries) {
    if (entry.value == label) return entry.key;
  }
  return null;
}

Shift getCurrentShift(DateTime date) {
  final minutes = date.hour * 60 + date.minute;
  final isSunday = date.weekday == DateTime.sunday;

  // Domingos / festivos
  if (isSunday) {
    if (minutes >= 6 * 60 && minutes <= 19 * 60 + 20) {
      return Shift.holiday;
    }
    return Shift.outOfShift;
  }

  // Lunes a sábado
  if (minutes >= 6 * 60 && minutes <= 10 * 60 + 54) {
    return Shift.morning;
  }
  if (minutes >= 10 * 60 + 55 && minutes <= 13 * 60 + 58) {
    return Shift.afternoon1;
  }
  if (minutes >= 13 * 60 + 59 && minutes <= 15 * 60 + 23) {
    return Shift.afternoon2;
  }
  if (minutes >= 15 * 60 + 24 && minutes <= 22 * 60 + 24) {
    return Shift.night1;
  }
  if (minutes >= 22 * 60 + 25 && minutes <= 22 * 60 + 30) {
    return Shift.night2;
  }

  return Shift.outOfShift;
}
