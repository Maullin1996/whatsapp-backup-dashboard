class AuthenticatedUser {
  final String id;
  final String email;
  final bool isAdmin;
  final bool isSuperAdmin; // ← nuevo

  AuthenticatedUser({
    required this.id,
    required this.email,
    required this.isAdmin,
    required this.isSuperAdmin, // ← nuevo
  });
}
