import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';

Future<AuthenticatedUser> mapToDomain(User user) async {
  final idTokenResult = await user.getIdTokenResult(true);
  final isAdmin = idTokenResult.claims?['admin'] == true;
  return AuthenticatedUser(
    id: user.uid,
    email: user.email ?? '',
    isAdmin: isAdmin,
  );
}
