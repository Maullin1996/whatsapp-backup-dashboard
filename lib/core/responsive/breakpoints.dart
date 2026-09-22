class AppBreakpoints {
  const AppBreakpoints._();

  static const double mobile = 600;

  /// Breakpoint del layout dividido (lista | conversación) de `HomePage`.
  /// Es más ancho que [mobile] porque a partir de aquí conviven la lista de
  /// chats y el panel de conversación lado a lado.
  static const double homeSplit = 700;
}
