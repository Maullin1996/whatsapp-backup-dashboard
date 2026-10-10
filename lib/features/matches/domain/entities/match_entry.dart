import 'package:freezed_annotation/freezed_annotation.dart';

part 'match_entry.freezed.dart';

/// Un número registrado por el Revisor que coincidió con un número ganador,
/// con lo necesario para mostrar el contexto y navegar de vuelta a la imagen
/// (ver `image-review-domain`, regla 7, y `image-review-firebase-integration`
/// § "Redirección liviana" — no hace falta el `Message` completo).
@freezed
abstract class MatchEntry with _$MatchEntry {
  const factory MatchEntry({
    /// El número tal cual lo anotó el Revisor (conserva ceros a la
    /// izquierda; ver `findMatches`).
    required String numero,

    /// Identificador de la lotería del comprobante donde el Revisor anotó el
    /// número (`lib/core/lotteries/lotteries.dart`). Null o fuera de la lista
    /// en un registro viejo de texto libre: esa entrada nunca coincide.
    required String? loteria,
    required String messageId,
    required String chatJid,
    required String groupName,
    required String senderName,
    required String localTime,

    /// Referencia de la imagen en Storage (nunca la imagen ni una URL).
    required String storagePath,

    /// Etiqueta larga en español, igual que `Message.shift`.
    required String shift,

    /// Día de la jornada (`yyyy-MM-dd`), igual que `Message.fechaJornada`.
    required String fechaJornada,

    /// Correo del Revisor que registró la imagen; vacío si no se conoce.
    @Default('') String revisorEmail,

    /// Código que el Revisor anotó para la imagen; null en un registro viejo.
    String? codigo,

    /// Número(s) completo(s) de la lotería con los que coincidió [numero]
    /// (p. ej. "4606" cuando el Revisor anotó "606"); ver
    /// `winningNumbersFor`. Vacío si no se calculó.
    @Default(<String>[]) List<String> winningNumbers,
  }) = _MatchEntry;
}
