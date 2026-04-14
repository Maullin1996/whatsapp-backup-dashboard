import 'package:cloud_functions/cloud_functions.dart';
import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/datasources/admin_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/repositories/admin_repository.dart';

class AdminRepositoryImpl implements AdminRepository {
  final AdminDatasource _datasource;

  const AdminRepositoryImpl(this._datasource);

  @override
  Future<Either<AdminFailure, List<AppUser>>> listUsers() async {
    try {
      return Right(await _datasource.listUsers());
    } on FirebaseFunctionsException catch (e) {
      return Left(mapFunctionsException(e));
    } catch (e) {
      return Left(AdminFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<AdminFailure, List<Group>>> listGroups() async {
    try {
      return Right(await _datasource.listGroups());
    } on FirebaseFunctionsException catch (e) {
      return Left(mapFunctionsException(e));
    } catch (e) {
      return Left(AdminFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<AdminFailure, AppUser>> createUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      return Right(
        await _datasource.createUser(
          email: email,
          password: password,
          displayName: displayName,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      return Left(mapFunctionsException(e));
    } catch (e) {
      return Left(AdminFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<AdminFailure, Unit>> updatePassword({
    required String uid,
    required String newPassword,
  }) async {
    try {
      await _datasource.updatePassword(uid: uid, newPassword: newPassword);
      return const Right(unit);
    } on FirebaseFunctionsException catch (e) {
      return Left(mapFunctionsException(e));
    } catch (e) {
      return Left(AdminFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<AdminFailure, Unit>> toggleUserStatus({
    required String uid,
    required bool disabled,
  }) async {
    try {
      await _datasource.toggleUserStatus(uid: uid, disabled: disabled);
      return const Right(unit);
    } on FirebaseFunctionsException catch (e) {
      return Left(mapFunctionsException(e));
    } catch (e) {
      return Left(AdminFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<AdminFailure, Unit>> updateUserGroups({
    required String uid,
    required List<String> allowedGroups,
  }) async {
    try {
      await _datasource.updateUserGroups(
        uid: uid,
        allowedGroups: allowedGroups,
      );
      return const Right(unit);
    } on FirebaseFunctionsException catch (e) {
      return Left(mapFunctionsException(e));
    } catch (e) {
      return Left(AdminFailure.unknown(e.toString()));
    }
  }

  @override
  Future<Either<AdminFailure, Unit>> deleteUser({required String uid}) async {
    try {
      await _datasource.deleteUser(uid: uid);
      return const Right(unit);
    } on FirebaseFunctionsException catch (e) {
      return Left(mapFunctionsException(e));
    } catch (e) {
      return Left(AdminFailure.unknown(e.toString()));
    }
  }
}
