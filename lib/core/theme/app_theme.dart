import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_radius.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_spacing.dart';

/// Tema global de la app (`MaterialApp.router(theme: AppTheme.light)`).
///
/// Centraliza los defaults que antes se repetían en cada widget (color de
/// botones, radios de tarjetas/diálogos, color de switches/checkboxes,
/// AppBar blanco, etc.) para que un widget "de fábrica"
/// (`ElevatedButton`, `Card`, `Dialog`, `Switch`...) ya salga consistente
/// con el resto de la app sin tener que pasarle `style`/`decoration` a mano.
///
/// Los widgets pueden seguir sobreescribiendo puntualmente con `copyWith`
/// o parámetros propios cuando necesiten un caso especial (ej. el botón rojo
/// de "Eliminar"); esto solo fija el caso común.
abstract class AppTheme {
  const AppTheme._();

  // Verde de marca, opaco (AppColors.primaryGreen lleva alpha 184 pensado
  // para usarse como color de fondo directo, no como semilla de ColorScheme).
  static const _brandGreen = Color(0xFF2FD017);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.screenBackground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brandGreen,
      primary: _brandGreen,
      secondary: AppColors.accentTeal,
      error: AppColors.errorMessage,
      surface: Colors.white,
      brightness: Brightness.light,
    ),

    // ── AppBar ──────────────────────────────
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.primaryGreen,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    ),

    // ── Botones ─────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.green),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        side: const BorderSide(color: AppColors.primaryGreen),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: Colors.white,
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        iconColor: WidgetStatePropertyAll(Colors.black87),
      ),
    ),

    // ── Tarjetas / diálogos / bottom sheets ──
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogAll),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.pill),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.cardAll),
    ),

    // ── Inputs ──────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppRadius.dialogAll,
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.dialogAll,
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.dialogAll,
        borderSide: const BorderSide(color: AppColors.inputBorder, width: 2),
      ),
      floatingLabelStyle: const TextStyle(color: Colors.black),
    ),

    // ── Selección / control ─────────────────
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primaryGreen
            : Colors.grey.shade300,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primaryGreen
            : Colors.transparent,
      ),
    ),
    radioTheme: const RadioThemeData(
      fillColor: WidgetStatePropertyAll(AppColors.primaryGreen),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.loadingColor,
    ),

    // ── Otros ───────────────────────────────
    dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.grey.shade100,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.pillAll),
      labelStyle: const TextStyle(fontSize: 12),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonAll),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(AppRadius.thumbnail),
      ),
    ),
  );
}
