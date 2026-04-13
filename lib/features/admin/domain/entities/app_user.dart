class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final bool disabled;
  final List<String> allowedGroups;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.disabled,
    required this.allowedGroups,
  });
}
