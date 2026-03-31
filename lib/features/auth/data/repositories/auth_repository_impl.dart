//auth_repository_impl.dart
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
import 'package:whatsapp_monitor_viewer/features/auth/data/datasources/firebase_auth_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/helpers/map_to_domain.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDatasource _datasource;

  const AuthRepositoryImpl(this._datasource);

  @override
  Future<Either<AuthFailure, AuthenticatedUser?>> getCurrentUser() async {
    try {
      final user = await _datasource.getCurrentUser();

      if (user == null) {
        return const Right(null);
      }

      return Right(mapToDomain(user));
    } on AuthFailure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(AuthFailure.unknown());
    }
  }

  @override
  Future<Either<AuthFailure, AuthenticatedUser>> login({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _datasource.login(email: email, password: password);
      return Right(mapToDomain(user));
    } on AuthFailure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(AuthFailure.unknown());
    }
  }

  @override
  Future<Either<AuthFailure, Unit>> logout() async {
    try {
      await _datasource.logout();
      return const Right(unit);
    } on AuthFailure catch (failure) {
      return Left(failure);
    } catch (_) {
      return const Left(AuthFailure.unknown());
    }
  }
}
