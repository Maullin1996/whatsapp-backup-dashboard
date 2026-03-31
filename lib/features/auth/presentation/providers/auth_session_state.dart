//auth_session_state.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';

part 'auth_session_state.freezed.dart';

@freezed
class AuthSessionState with _$AuthSessionState {
  const factory AuthSessionState.loading() = _Loading;
  const factory AuthSessionState.authenticated(AuthenticatedUser user) =
      _Authenticated;
  const factory AuthSessionState.unauthenticated() = _Unauthenticated;
}
