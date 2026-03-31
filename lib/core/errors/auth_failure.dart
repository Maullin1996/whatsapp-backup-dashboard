import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_failure.freezed.dart';

@freezed
abstract class AuthFailure with _$AuthFailure {
  const factory AuthFailure.invalidEmail() = _InvalidEmail;
  const factory AuthFailure.wrongPassword() = _WrongPassword;
  const factory AuthFailure.userNotFound() = _UserNotFound;
  const factory AuthFailure.userDisabled() = _UserDisabled;
  const factory AuthFailure.networkError() = _NetworkError;
  const factory AuthFailure.tooManyRequests() = _TooManyRequests;
  const factory AuthFailure.unknown() = _Unknown;
}

extension AuthFailureMessageX on AuthFailure {
  String get message => switch (this) {
    _InvalidEmail() => 'Correo inválido',
    _WrongPassword() => 'Contraseña Incorrecta',
    _UserNotFound() => 'Usuario no encontrado',
    _UserDisabled() => 'Usuario deshabilitado',
    _NetworkError() => 'Error de conexión',
    _TooManyRequests() => 'Demasiados intentos',
    _Unknown() => 'Error inesperado',
    _ => 'Error inesperado',
  };
}
