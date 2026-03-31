//login_form_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';

part 'login_form_state.freezed.dart';

@freezed
abstract class LoginFormState with _$LoginFormState {
  const factory LoginFormState({
    @Default('') String email,
    @Default('') String password,
    @Default(false) bool isLoading,
    AuthFailure? error,
  }) = _LoginFormState;
}
