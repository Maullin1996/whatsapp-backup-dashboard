import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

part 'jornada_estado.freezed.dart';

/// Resultado de comparar lo que registraron Revisor y Sumador en una jornada.
///
/// Solo habla de DINERO (reconciliación de sumas) y de quién falta por
/// registrar. No es una alerta de imágenes sin registrar (señal aparte, ver
/// `image-review-domain`).
@freezed
sealed class JornadaEstado with _$JornadaEstado {
  /// Ambos registraron y las sumas coinciden.
  const factory JornadaEstado.cuadra() = JornadaCuadra;

  /// Ambos registraron y las sumas difieren. [diferencia] es el valor
  /// absoluto de la diferencia, en pesos (siempre > 0).
  const factory JornadaEstado.descuadre({required int diferencia}) =
      JornadaDescuadre;

  /// Falta que registre alguno de los dos (o los dos): [faltan] dice cuáles.
  const factory JornadaEstado.pendiente({required Set<ReviewRole> faltan}) =
      JornadaPendiente;
}
