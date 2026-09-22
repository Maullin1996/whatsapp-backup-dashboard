import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';

/// Estilos de texto reutilizados en varias features.
///
/// La app no define un `ThemeData.textTheme` global (ver CLAUDE.md /
/// skill de UI): estos estilos son puntuales y se combinan con
/// `Theme.of(context).textTheme` vía `copyWith` cuando aplica.
abstract class AppTypography {
  const AppTypography._();

  /// Nombre del remitente dentro de una burbuja de mensaje.
  static TextStyle senderName(BuildContext context) =>
      Theme.of(context).textTheme.labelLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: Colors.teal,
      );

  /// Hora/fecha de un mensaje.
  static TextStyle timestamp(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.grey);

  /// Título de un header de conversación / diálogo.
  static TextStyle headerTitle(BuildContext context) =>
      Theme.of(
        context,
      ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w600);

  /// Título del AppBar del panel de admin.
  static const TextStyle adminAppBarTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryGreen,
  );

  /// Texto de badges/chips (rol de usuario, filtro activo).
  static const TextStyle badge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  /// Nombre del chat en el tile de la lista.
  static const TextStyle chatTileTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  /// Iniciales sobre el avatar circular de un chat.
  static const TextStyle avatarInitials = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
}
