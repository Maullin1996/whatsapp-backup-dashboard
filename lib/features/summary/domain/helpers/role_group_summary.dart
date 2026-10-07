import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/imagenes_faltantes.dart';

/// Lo que registró un rol (Revisor o Sumador) en un grupo durante un día,
/// jornada por jornada. Es lo que muestra la tarjeta del rol en la lista del
/// Resumen y su pantalla de detalle.
class RoleGroupSummary {
  final ReviewRole rol;
  final List<RoleJornada> jornadas;

  const RoleGroupSummary({required this.rol, required this.jornadas});

  /// Resumen de [rol] sobre las jornadas de UN grupo ([groupJornadas]).
  factory RoleGroupSummary.of(
    ReviewRole rol,
    List<JornadaSummary> groupJornadas,
    DateTime now,
  ) => RoleGroupSummary(
    rol: rol,
    jornadas: [
      for (final j in groupJornadas)
        RoleJornada(
          summary: j,
          role: _roleOf(rol, j),
          imagenesFaltantes: imagenesFaltantes(j, rol, now) ?? 0,
        ),
    ],
  );

  static RoleSummary _roleOf(ReviewRole rol, JornadaSummary j) =>
      rol == ReviewRole.revisor ? j.revisor : j.sumador;

  /// Jornadas que este rol ya registró.
  List<RoleJornada> get registradas => [
    for (final j in jornadas)
      if (j.role.registrado) j,
  ];

  /// Jornadas del grupo en las que este rol todavía no registró nada.
  List<RoleJornada> get faltantes => [
    for (final j in jornadas)
      if (!j.role.registrado) j,
  ];

  /// Suma de los totales de todas las jornadas registradas, en pesos.
  int get total => registradas.fold(0, (sum, j) => sum + j.role.totalSuma);

  int get tickets =>
      registradas.fold(0, (sum, j) => sum + j.role.cantidadTickets);

  int get imagenes =>
      registradas.fold(0, (sum, j) => sum + j.role.cantidadImagenes);

  /// Imágenes de jornadas terminadas que este rol no registró.
  int get imagenesSinRegistrar =>
      registradas.fold(0, (sum, j) => sum + j.imagenesFaltantes);

  /// Nada pendiente: todas las jornadas registradas y sin imágenes sueltas.
  bool get completo => faltantes.isEmpty && imagenesSinRegistrar == 0;
}

/// Una jornada vista desde un rol.
class RoleJornada {
  final JornadaSummary summary;
  final RoleSummary role;

  /// Imágenes de la jornada (ya terminada) que el rol no registró; 0 si no
  /// aplica.
  final int imagenesFaltantes;

  const RoleJornada({
    required this.summary,
    required this.role,
    required this.imagenesFaltantes,
  });
}
