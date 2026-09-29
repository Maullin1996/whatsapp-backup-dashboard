import 'package:cloud_functions/cloud_functions.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

part 'admin_failure.freezed.dart';

@freezed
abstract class AdminFailure with _$AdminFailure {
  const factory AdminFailure.permissionDenied() = _PermissionDenied;
  const factory AdminFailure.invalidArgument() = _InvalidArgument;
  const factory AdminFailure.emailAlreadyExists() = _EmailAlreadyExists;

  /// `already-exists` de `updateReviewShifts`: uno o más `(chatJid, shift)`
  /// del payload ya están cubiertos por otra persona del MISMO rol. Trae
  /// TODAS las tuplas en conflicto (el backend ya las devuelve todas, no solo
  /// la primera) para que la UI las resalte de una vez. Caso propio, NO el
  /// mismo código `already-exists` que usa `emailAlreadyExists` para
  /// `createUser` — se mapea aparte, sin tocar [mapFunctionsException].
  const factory AdminFailure.reviewShiftConflict(List<ReviewShift> conflicts) =
      _ReviewShiftConflict;
  const factory AdminFailure.unknown(String message) = _Unknown;
}

extension AdminFailureMessageX on AdminFailure {
  String get message => switch (this) {
    _PermissionDenied() => 'No tienes permisos para realizar esta acción',
    _InvalidArgument() => 'Datos inválidos, verifica los campos',
    _EmailAlreadyExists() => 'El correo ya está registrado',
    _ReviewShiftConflict() =>
      'Ese grupo y esa jornada ya están asignados a otro Revisor/Sumador.',
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
