//firebase_auth_datasource_impl.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/map_auth_exception.dart';
import 'package:whatsapp_monitor_viewer/features/auth/data/datasources/firebase_auth_datasource.dart';

class FirebaseAuthDatasourceImpl implements FirebaseAuthDatasource {
  final FirebaseAuth _firebaseAuth;

  FirebaseAuthDatasourceImpl(this._firebaseAuth);

  @override
  Future<User?> getCurrentUser() async {
    return _firebaseAuth.currentUser;
  }

  @override
  Future<User> login({required String email, required String password}) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        throw const AuthFailure.unknown();
      }

      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw mapFirebaseException(e);
    }
  }

  @override
  Future<void> logout() async {
    await _firebaseAuth.signOut();
  }
}
