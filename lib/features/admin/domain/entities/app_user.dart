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
}
