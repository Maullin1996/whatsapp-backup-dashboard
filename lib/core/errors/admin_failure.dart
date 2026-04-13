import 'package:cloud_functions/cloud_functions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_failure.freezed.dart';

@freezed
abstract class AdminFailure with _$AdminFailure {
  const factory AdminFailure.permissionDenied() = _PermissionDenied;
  const factory AdminFailure.invalidArgument() = _InvalidArgument;
  const factory AdminFailure.emailAlreadyExists() = _EmailAlreadyExists;
  const factory AdminFailure.unknown(String message) = _Unknown;
}

extension AdminFailureMessageX on AdminFailure {
  String get message => switch (this) {
    _PermissionDenied() => 'No tienes permisos para realizar esta acción',
    _InvalidArgument() => 'Datos inválidos, verifica los campos',
    _EmailAlreadyExists() => 'El correo ya está registrado',
    _Unknown(:final message) => message,
    AdminFailure() => throw UnimplementedError(),
  };
}

AdminFailure mapFunctionsException(FirebaseFunctionsException e) {
  return switch (e.code) {
    'permission-denied' => const AdminFailure.permissionDenied(),
    'invalid-argument' => const AdminFailure.invalidArgument(),
    'already-exists' => const AdminFailure.emailAlreadyExists(),
    _ => AdminFailure.unknown(e.message ?? 'Error inesperado'),
  };
}
