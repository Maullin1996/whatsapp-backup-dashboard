/// Duraciones de animación y transición usadas en la app.
///
/// La app usa animaciones cortas (120–400 ms) y evita reconstruir listas
/// completas.
abstract class AppDurations {
  const AppDurations._();

  /// 120 ms — micro-interacciones (hover/tap de un tile de chat).
  static const Duration hover = Duration(milliseconds: 120);

  /// 180 ms — fade-out corto (botón "ir al último mensaje").
  static const Duration fadeOut = Duration(milliseconds: 180);

  /// 200 ms — transiciones de estado puntuales (zoom/fade de imagen, scroll
  /// a un mensaje).
  static const Duration quick = Duration(milliseconds: 200);

  /// 220 ms — transición entre pantallas en móvil (lista ↔ conversación),
  /// slide del botón "ir al último mensaje".
  static const Duration pageTransition = Duration(milliseconds: 220);

  /// 250 ms — aparición animada de un item de la lista de chats.
  static const Duration chatItemAppear = Duration(milliseconds: 250);

  /// 260 ms — aparición animada de un mensaje.
  static const Duration messageItemAppear = Duration(milliseconds: 260);

  /// 400 ms — `AnimatedSwitcher` entre estados de carga/vacío/datos.
  static const Duration stateSwitch = Duration(milliseconds: 400);

  /// 800 ms — animación de scroll (ir al último mensaje).
  static const Duration scrollToLatest = Duration(milliseconds: 800);

  /// 1200 ms — periodo del shimmer de carga (`AppShimmer`).
  static const Duration shimmer = Duration(milliseconds: 1200);
}
