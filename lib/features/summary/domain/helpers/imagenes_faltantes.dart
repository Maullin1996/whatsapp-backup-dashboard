import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';

/// Id del documento de `shift_image_counts` (el contador que publica el bot)
/// para un chat, día y jornada: `${chatJid}_${yyyy-MM-dd}_${shiftKey}`. El
/// `shiftKey` es el nombre del enum [Shift], tal cual. `null` para
/// [Shift.outOfShift]: el bot no publica contador de esa "jornada".
String? shiftImageCountDocId(
  String chatJid,
  String fechaJornada,
  Shift shift,
) => shift == Shift.outOfShift
    ? null
    : '${chatJid}_${fechaJornada}_${shift.name}';

/// Cuántas imágenes de la jornada le faltan por registrar a [rol], según el
/// contador del bot. Señal solo informativa, separada del estado de dinero.
///
/// `null` = no aplica: la jornada no terminó a la hora [now] (el contador
/// puede seguir creciendo), el rol no registró nada (eso ya lo dice el badge
/// "Falta [rol]"), o la etiqueta de la jornada no se reconoce. `0` si el rol
/// registró igual o más que el contador (nunca negativo); si no, la
/// diferencia.
int? imagenesFaltantes(JornadaSummary resumen, ReviewRole rol, DateTime now) {
  final role = switch (rol) {
    ReviewRole.revisor => resumen.revisor,
    ReviewRole.sumador => resumen.sumador,
  };
  if (!role.registrado) return null;

  final shift = shiftFromLabel(resumen.shift);
  if (shift == null || !jornadaTerminada(resumen.fechaJornada, shift, now)) {
    return null;
  }

  final diferencia = resumen.imagenesEnJornada - role.cantidadImagenes;
  return diferencia > 0 ? diferencia : 0;
}
