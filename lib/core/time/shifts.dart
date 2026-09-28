import 'package:whatsapp_monitor_viewer/core/time/bogota_time.dart';

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

/// Último minuto INCLUSIVO de cada jornada asignable, en minutos desde la
/// medianoche. Debe coincidir con los límites de [getCurrentShift] (lo
/// verifica `shifts_end_test.dart`). [Shift.outOfShift] no tiene fin.
const shiftLastMinute = <Shift, int>{
  Shift.morning: 10 * 60 + 54,
  Shift.afternoon1: 13 * 60 + 58,
  Shift.afternoon2: 15 * 60 + 23,
  Shift.night1: 22 * 60 + 24,
  Shift.night2: 22 * 60 + 30,
  Shift.holiday: 19 * 60 + 20,
};

final _fechaJornadaFormat = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Si la jornada [shift] del día [fechaJornada] (`yyyy-MM-dd`) ya terminó a la
/// hora [now]: desde el minuto siguiente a su último minuto inclusivo (la
/// mañana termina a las 10:55:00), sin margen.
///
/// La fecha de la jornada y [now] se comparan en hora de Bogotá
/// ([bogotaWallClock]), no en la zona del dispositivo. Por eso un día anterior
/// a hoy siempre terminó y un día futuro nunca. `false` para
/// [Shift.outOfShift] y para una fecha con formato inválido.
bool jornadaTerminada(String fechaJornada, Shift shift, DateTime now) {
  final lastMinute = shiftLastMinute[shift];
  final match = _fechaJornadaFormat.firstMatch(fechaJornada);
  if (lastMinute == null || match == null) return false;

  final endOfShift = DateTime.utc(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ).add(Duration(minutes: lastMinute + 1));
  return !bogotaWallClock(now).isBefore(endOfShift);
}
