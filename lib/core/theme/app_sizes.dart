/// Tamaños y anchos máximos de contenido usados en layouts responsive.
///
/// Se centran con `Center` + `ConstrainedBox(maxWidth: ...)` en desktop.
/// Ver también `lib/core/responsive/breakpoints.dart` para el breakpoint
/// mobile/desktop.
abstract class AppSizes {
  const AppSizes._();

  /// Ancho máximo del formulario de login.
  static const double loginFormMaxWidth = 400;

  /// Ancho máximo de las listas/paneles del panel de admin.
  static const double adminPanelMaxWidth = 800;

  /// Ancho máximo de una burbuja de mensaje en desktop.
  static const double messageBubbleMaxWidth = 420;

  /// Ancho máximo de un estado vacío centrado.
  static const double emptyStateMaxWidth = 420;

  /// Radio del avatar circular de un chat en la lista.
  static const double chatAvatarRadius = 27.5;

  /// Fracción del ancho de pantalla que ocupa la lista de chats en desktop,
  /// acotada entre [chatListMinWidth] y [chatListMaxWidth].
  static const double chatListWidthFraction = 0.34;
  static const double chatListMinWidth = 320;
  static const double chatListMaxWidth = 420;

  static double chatListWidth(double screenWidth) =>
      (screenWidth * chatListWidthFraction).clamp(
        chatListMinWidth,
        chatListMaxWidth,
      );
}
