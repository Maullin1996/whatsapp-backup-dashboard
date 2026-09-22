/// Escala de espaciado de la app, en múltiplos de 4.
///
/// Úsala en vez de números mágicos en `EdgeInsets`, `SizedBox`, `gap`, etc.
abstract class AppSpacing {
  const AppSpacing._();

  /// 4 — separaciones mínimas (icono-texto, badges).
  static const double xs = 4;

  /// 8 — padding de tarjetas/tiles, separación entre elementos relacionados.
  static const double sm = 8;

  /// 12 — padding de listas/tarjetas, separación entre bloques.
  static const double md = 12;

  /// 16 — padding horizontal estándar de pantalla móvil, headers, diálogos.
  static const double lg = 16;

  /// 24 — separación entre secciones, padding de diálogos/paneles amplios.
  static const double xl = 24;
}
