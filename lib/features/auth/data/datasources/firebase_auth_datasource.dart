//firebase_auth_datasource.dart
import 'package:firebase_auth/firebase_auth.dart';

abstract class FirebaseAuthDatasource {
  Future<User> login({required String email, required String password});

  Future<void> logout();

  Future<User?> getCurrentUser();
}
