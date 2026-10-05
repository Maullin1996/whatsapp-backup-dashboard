import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/imagenes_faltantes.dart';

/// Qué jornadas muestra el panel del Resumen.
enum SummaryFilter {
  todas,
  descuadre,
  pendiente,

  /// Jornadas terminadas con imágenes que algún rol no registró (señal
  /// informativa, independiente del estado de dinero).
  imagenes,
  cuadra,
}

/// Imágenes sin registrar de una jornada, sumando los dos roles (ver
/// [imagenesFaltantes]: solo cuenta en jornadas terminadas y de roles que ya
/// registraron algo).
int imagenesSinRegistrarEn(JornadaSummary summary, DateTime now) =>
    (imagenesFaltantes(summary, ReviewRole.revisor, now) ?? 0) +
    (imagenesFaltantes(summary, ReviewRole.sumador, now) ?? 0);

/// Si [summary] entra en [filter].
bool matchesSummaryFilter(
  JornadaSummary summary,
  SummaryFilter filter,
  DateTime now,
) => switch (filter) {
  SummaryFilter.todas => true,
  SummaryFilter.descuadre => summary.estado is JornadaDescuadre,
  SummaryFilter.pendiente => summary.estado is JornadaPendiente,
  SummaryFilter.cuadra => summary.estado is JornadaCuadra,
  SummaryFilter.imagenes => imagenesSinRegistrarEn(summary, now) > 0,
};

/// Cifras del panel informativo del Resumen para un día.
class SummaryOverview {
  final int jornadas;
  final int grupos;
  final int cuadran;
  final int descuadres;
  final int pendientes;

  /// Suma de las diferencias (en pesos) de las jornadas con descuadre.
  final int totalDiferencias;

  /// Jornadas con al menos una imagen sin registrar.
  final int jornadasConImagenes;

  /// Total de imágenes sin registrar (los dos roles, todas las jornadas).
  final int imagenesSinRegistrar;

  const SummaryOverview({
    required this.jornadas,
    required this.grupos,
    required this.cuadran,
    required this.descuadres,
    required this.pendientes,
    required this.totalDiferencias,
    required this.jornadasConImagenes,
    required this.imagenesSinRegistrar,
  });

  factory SummaryOverview.of(List<JornadaSummary> summaries, DateTime now) {
    var cuadran = 0, descuadres = 0, pendientes = 0, diferencias = 0;
    var jornadasConImagenes = 0, imagenes = 0;
    for (final summary in summaries) {
      switch (summary.estado) {
        case JornadaCuadra():
          cuadran++;
        case JornadaDescuadre(:final diferencia):
          descuadres++;
          diferencias += diferencia;
        case JornadaPendiente():
          pendientes++;
      }
      final faltan = imagenesSinRegistrarEn(summary, now);
      if (faltan > 0) {
        jornadasConImagenes++;
        imagenes += faltan;
      }
    }
    return SummaryOverview(
      jornadas: summaries.length,
      grupos: summaries.map((s) => s.chatJid).toSet().length,
      cuadran: cuadran,
      descuadres: descuadres,
      pendientes: pendientes,
      totalDiferencias: diferencias,
      jornadasConImagenes: jornadasConImagenes,
      imagenesSinRegistrar: imagenes,
    );
  }

  /// Cuántas jornadas hay en [filter].
  int countOf(SummaryFilter filter) => switch (filter) {
    SummaryFilter.todas => jornadas,
    SummaryFilter.descuadre => descuadres,
    SummaryFilter.pendiente => pendientes,
    SummaryFilter.imagenes => jornadasConImagenes,
    SummaryFilter.cuadra => cuadran,
  };
}

/// Gravedad de una jornada para ordenar los grupos: 0 descuadre, 1 pendiente,
/// 2 imágenes sin registrar, 3 todo en orden.
int _severity(JornadaSummary summary, DateTime now) => switch (summary.estado) {
  JornadaDescuadre() => 0,
  JornadaPendiente() => 1,
  JornadaCuadra() => imagenesSinRegistrarEn(summary, now) > 0 ? 2 : 3,
};

/// Jornadas agrupadas por grupo (`chatJid`), con los grupos que necesitan
/// atención primero (según su jornada más grave); a igual gravedad se
/// conserva el orden en que llegan. Dentro de cada grupo las jornadas quedan
/// en el orden de llegada.
List<List<JornadaSummary>> groupsBySeverity(
  List<JornadaSummary> summaries,
  DateTime now,
) {
  final byGroup = <String, List<JornadaSummary>>{};
  for (final summary in summaries) {
    byGroup.putIfAbsent(summary.chatJid, () => []).add(summary);
  }
  int worst(List<JornadaSummary> group) =>
      group.map((s) => _severity(s, now)).reduce((a, b) => a < b ? a : b);

  final groups = byGroup.values.toList();
  final order = {for (var i = 0; i < groups.length; i++) groups[i]: i};
  return groups..sort((a, b) {
    final bySeverity = worst(a).compareTo(worst(b));
    return bySeverity != 0 ? bySeverity : order[a]!.compareTo(order[b]!);
  });
}
