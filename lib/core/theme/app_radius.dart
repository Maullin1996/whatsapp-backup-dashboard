import 'package:flutter/material.dart';

/// Radios de borde usados en la app.
///
/// Expone el valor en `double` (para `BorderRadius.circular`) y también
/// como `BorderRadius` ya resuelto para los casos más comunes.
abstract class AppRadius {
  const AppRadius._();

  /// 6 — miniaturas, thumbnails de imagen, celdas de skeleton pequeñas.
  static const double thumbnail = 6;

  /// 8 — botones, burbujas de mensaje, chips de acción.
  static const double button = 8;

  /// 10 — tarjetas de skeleton, contenedores de drawer/bottom sheet.
  static const double tile = 10;

  /// 12 — tarjetas y tiles de lista (chat tile, loading card).
  static const double card = 12;

  /// 14 — tarjetas de skeleton del panel de admin.
  static const double skeletonCard = 14;

  /// 16 — inputs y diálogos.
  static const double dialog = 16;

  /// 18 — buscadores.
  static const double search = 18;

  /// 20 — chips/badges tipo píldora, barra de zoom del visor de imágenes.
  static const double pill = 20;

  static const BorderRadius buttonAll = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius tileAll = BorderRadius.all(Radius.circular(tile));
  static const BorderRadius dialogAll = BorderRadius.all(
    Radius.circular(dialog),
  );
  static const BorderRadius searchAll = BorderRadius.all(
    Radius.circular(search),
  );
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}
