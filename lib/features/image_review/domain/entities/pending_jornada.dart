import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_jornada.freezed.dart';

/// Una jornada de un chat que tiene registros pendientes de subir, con
/// cuántos son. Es solo un resumen: los registros se piden con `getPending`.
@freezed
abstract class PendingJornada with _$PendingJornada {
  const factory PendingJornada({
    /// Día de la jornada (`yyyy-MM-dd`).
    required String fechaJornada,

    /// Mismo texto que guarda `ImageReviewRecord.shift`.
    required String shift,
    required int cantidad,
  }) = _PendingJornada;
}
