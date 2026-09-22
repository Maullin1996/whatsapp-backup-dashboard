import 'package:flutter/material.dart';

class AppColors {
  /// Acento principal: FAB, switches, avatares activos, botones primarios.
  static const primaryGreen = Color.fromARGB(184, 47, 208, 23);

  /// Spinners / indicadores de carga.
  static const loadingColor = Colors.green;

  /// Errores, acciones destructivas.
  static const errorMessage = Colors.red;

  /// Gradiente de login (topLeft → bottomRight).
  static const upLoginBackground = Color.fromARGB(255, 189, 234, 214);
  static const downLoginBackground = Color(0xFFF0F9E8);

  /// Relleno de inputs del login.
  static const inputBackground = Color.fromARGB(96, 236, 248, 240);

  /// Borde de inputs (`CustomTextFormField`).
  static const inputBorder = Color.fromARGB(255, 167, 231, 200);

  /// Fondo de las pantallas de la app (beige gris); paneles de lista van
  /// sobre [Colors.white].
  static const screenBackground = Color.fromARGB(255, 240, 239, 236);

  /// Teal de acento secundario: badge de filtro activo, iconos activos,
  /// nombre del remitente.
  static const accentTeal = Color(0xFF00897B);

  /// Rol admin.
  static const roleAdmin = Colors.orange;

  /// Rol superAdmin.
  static const roleSuperAdmin = Colors.purple;

  /// Color de éxito (snackbars, confirmaciones).
  static const success = Colors.green;

  /// Divisores y bordes suaves.
  static Color divider = Colors.black.withValues(alpha: 0.12);

  /// Tile activo/seleccionado en listas.
  static const activeTile = Color.fromARGB(159, 236, 234, 234);
}
