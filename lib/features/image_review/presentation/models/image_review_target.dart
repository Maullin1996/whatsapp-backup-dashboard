/// Datos del mensaje (imagen) al que pertenece el formulario. Los toma quien
/// aloja el panel a partir del `Message`; el panel no conoce el feature
/// `messages`.
class ImageReviewTarget {
  final String messageId;
  final String chatJid;
  final String shift;

  const ImageReviewTarget({
    required this.messageId,
    required this.chatJid,
    required this.shift,
  });
}
