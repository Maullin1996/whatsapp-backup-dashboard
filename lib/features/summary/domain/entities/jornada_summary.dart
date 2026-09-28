import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';

part 'jornada_summary.freezed.dart';

/// Resumen de una jornada de un grupo en un día: lo que registró cada rol.
@freezed
abstract class JornadaSummary with _$JornadaSummary {
  const JornadaSummary._();

  const factory JornadaSummary({
    required String chatJid,

    /// Nombre del grupo, para mostrarlo sin ir a buscarlo.
    required String groupName,

    /// Día de la jornada (`yyyy-MM-dd`, el mismo formato que
    /// `ImageReviewRecord.fechaJornada`).
    required String fechaJornada,

    /// Mismo texto que guarda `ImageReviewRecord.shift`.
    required String shift,
    required RoleSummary revisor,
    required RoleSummary sumador,

    /// `lastIndex` del contador que publica el bot en `shift_image_counts`
    /// para este chat, día y jornada. Obligatorio a propósito: quien arma el
    /// resumen debe pasar 0 si el documento no existe (esa jornada no tuvo
    /// media), no dejarlo callado. Cuenta también audio, video y sticker, y puede
    /// tener huecos: solo sirve para el aviso informativo de imágenes sin
    /// registrar (ver `imagenesFaltantes`), nunca para el estado de dinero.
    required int imagenesEnJornada,
  }) = _JornadaSummary;

  /// Cuadra, descuadre (con la diferencia) o pendiente (con quién falta).
  ///
  /// La reconciliación es agregada por jornada: solo se comparan las dos
  /// sumas de totales, sin emparejar comprobante por comprobante.
  JornadaEstado get estado {
    final faltan = <ReviewRole>{
      if (!revisor.registrado) ReviewRole.revisor,
      if (!sumador.registrado) ReviewRole.sumador,
    };
    if (faltan.isNotEmpty) return JornadaEstado.pendiente(faltan: faltan);

    final diferencia = revisor.totalSuma - sumador.totalSuma;
    if (diferencia == 0) return const JornadaEstado.cuadra();
    return JornadaEstado.descuadre(diferencia: diferencia.abs());
  }
}
