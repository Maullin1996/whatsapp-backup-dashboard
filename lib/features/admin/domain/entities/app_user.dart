import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final bool disabled;
  final List<String> allowedGroups;
  final bool isAdmin; // ← nuevo
  final bool isSuperAdmin; // ← nuevo

  /// Rol de revisión de imágenes ('revisor'/'sumador'), o `null` si no tiene
  /// ninguno. Independiente de `isAdmin`/`isSuperAdmin`: un superAdmin puede
  /// tener también un rol de revisión.
  final ReviewRole? reviewRole;

  /// Grupos y jornadas que cubre bajo `reviewRole`. Vacía si no tiene rol, o
  /// si tiene rol pero todavía sin horarios asignados. Nunca `null`.
  final List<ReviewShift> reviewShifts;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.disabled,
    required this.allowedGroups,
    this.isAdmin = false, // ← nuevo
    this.isSuperAdmin = false, // ← nuevo
    this.reviewRole,
    this.reviewShifts = const [],
  });

  /// Sentinel para distinguir "no pasar `reviewRole`" (conservar el actual)
  /// de "pasar `reviewRole: null`" (limpiarlo de verdad) en [copyWith] — a
  /// diferencia del resto de los campos, `null` es un valor válido de destino
  /// para este uno (desactivar el rol), no solo "no cambiar".
  static const Object _unset = Object();

  /// Copia con los campos indicados cambiados. Usarlo en las actualizaciones
  /// optimistas en vez de reconstruir el usuario a mano: así nunca se pierden
  /// `isAdmin` / `isSuperAdmin` (un superAdmin se vería como usuario normal y
  /// la tarjeta le ofrecería "Hacer admin").
  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    bool? disabled,
    List<String>? allowedGroups,
    bool? isAdmin,
    bool? isSuperAdmin,
    Object? reviewRole = _unset,
    List<ReviewShift>? reviewShifts,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      disabled: disabled ?? this.disabled,
      allowedGroups: allowedGroups ?? this.allowedGroups,
      isAdmin: isAdmin ?? this.isAdmin,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      reviewRole: identical(reviewRole, _unset)
          ? this.reviewRole
          : reviewRole as ReviewRole?,
      reviewShifts: reviewShifts ?? this.reviewShifts,
    );
  }
}
