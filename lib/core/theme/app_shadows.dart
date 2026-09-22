import 'package:flutter/material.dart';

/// Sombras usadas en la app.
///
/// La app prefiere bordes finos y elevación mínima; las sombras grandes se
/// reservan para la tarjeta de login.
abstract class AppShadows {
  const AppShadows._();

  /// Sombra sutil de las burbujas de mensaje.
  static const List<BoxShadow> bubble = [
    BoxShadow(
      color: Colors.black38,
      blurRadius: 0.5,
      offset: Offset(0, 0.2),
      spreadRadius: 0.5,
    ),
  ];

  /// Sombra pronunciada de la tarjeta de login (único lugar con elevación
  /// fuerte en la app).
  static List<BoxShadow> loginCard = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 20,
      offset: const Offset(0, 5),
      spreadRadius: 5,
    ),
  ];
}
