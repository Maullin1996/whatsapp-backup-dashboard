/// Datos del mensaje (imagen) al que pertenece el formulario. Los toma quien
/// aloja el panel a partir del `Message`; el panel no conoce el feature
/// `messages`.
class ImageReviewTarget {
  final String messageId;
  final String chatJid;
  final String shift;

  /// Referencia de la imagen en Storage; se guarda en el registro.
  final String storagePath;

  /// Día de la jornada (`yyyy-MM-dd`, ver `fechaJornadaDe`); se guarda en el
  /// registro y sirve para consultar pendientes por jornada.
  final String fechaJornada;

  /// Hora local de la imagen y su número dentro de la jornada. Solo se
  /// muestran en el encabezado del panel; no forman parte del registro.
  final String? localTime;
  final int? shiftImageIndex;

  const ImageReviewTarget({
    required this.messageId,
    required this.chatJid,
    required this.shift,
    required this.storagePath,
    required this.fechaJornada,
    this.localTime,
    this.shiftImageIndex,
  });
}
