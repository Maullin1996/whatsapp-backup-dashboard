import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

/// Jornadas que [shifts] (las asignaciones del rol activo) cubre en [chatJid]
/// y que aplican a [date]: un domingo o festivo ([isHolidayOrSunday]) solo
/// `holiday`; otro día, las demás. En el orden del día (enum [Shift]), sin
/// repetir. `night2` y `outOfShift` nunca se ofrecen: no tienen rango en la
/// tabla y ninguna imagen cae en ellas (mismo criterio que el panel de
/// horarios de admin).
List<Shift> jornadasParaFecha(
  List<ReviewShift> shifts,
  String chatJid,
  DateTime date,
) {
  final holiday = isHolidayOrSunday(date);
  final result = {
    for (final s in shifts)
      if (s.chatJid == chatJid &&
          s.shift != Shift.outOfShift &&
          s.shift != Shift.night2 &&
          (s.shift == Shift.holiday) == holiday)
        s.shift,
  }.toList()..sort((a, b) => a.index.compareTo(b.index));
  return result;
}
