//auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/repositories/auth_repository.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  late final AuthRepository _repository;

  @override
  AuthSessionState build() {
    _repository = ref.read(authRepositoryProvider);
    _loadSession();
    return const AuthSessionState.loading();
  }

  Future<void> _loadSession() async {
    final result = await _repository.getCurrentUser();

    result.fold((_) => state = const AuthSessionState.unauthenticated(), (
      user,
    ) {
      if (user == null) {
        state = const AuthSessionState.unauthenticated();
      } else {
        state = AuthSessionState.authenticated(user);
      }
    });
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthSessionState.unauthenticated();
  }

  void setAuthenticated(AuthenticatedUser user) {
    state = AuthSessionState.authenticated(user);
  }
}
