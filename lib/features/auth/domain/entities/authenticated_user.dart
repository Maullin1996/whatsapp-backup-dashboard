class AuthenticatedUser {
  final String id;
  final String email;
  final bool isAdmin;

  AuthenticatedUser({
    required this.id,
    required this.email,
    required this.isAdmin,
  });
}
