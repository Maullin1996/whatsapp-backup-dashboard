class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final bool disabled;
  final List<String> allowedGroups;
  final bool isAdmin; // ← nuevo
  final bool isSuperAdmin; // ← nuevo

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.disabled,
    required this.allowedGroups,
    this.isAdmin = false, // ← nuevo
    this.isSuperAdmin = false, // ← nuevo
  });

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
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      disabled: disabled ?? this.disabled,
      allowedGroups: allowedGroups ?? this.allowedGroups,
      isAdmin: isAdmin ?? this.isAdmin,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
    );
  }
}
