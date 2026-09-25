class AppBreakpoints {
  const AppBreakpoints._();

  static const double mobile = 600;

  /// Breakpoint del layout dividido (lista | conversación) de `HomePage`.
  /// Es más ancho que [mobile] porque a partir de aquí conviven la lista de
  /// chats y el panel de conversación lado a lado.
  static const double homeSplit = 700;

  /// A partir de este ancho el visor de imágenes muestra el panel del
  /// formulario del Revisor junto a la imagen (y activa el bloqueo de
  /// avance). Es la clase de ventana "expanded" de Material 3: entre
  /// [mobile] (600) y 840 hay tablets verticales y celulares horizontales,
  /// donde el panel dejaría la imagen demasiado angosta.
  ///
  /// Adoptado, pendiente de validar en dispositivos reales (tablet
  /// vertical/horizontal, laptop).
  static const double reviewForm = 840;
}
