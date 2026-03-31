//login_form_notifier.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/repositories/auth_repository.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/login_form_state.dart';

class LoginFormNotifier extends Notifier<LoginFormState> {
  late final AuthRepository _repository;

  @override
  LoginFormState build() {
    _repository = ref.read(authRepositoryProvider);
    return const LoginFormState();
  }

  void onEmailChanged(String value) {
    state = state.copyWith(email: value, error: null);
  }

  void onPasswordChanged(String value) {
    state = state.copyWith(password: value, error: null);
  }

  Future<void> submit() async {
    if (state.email.isEmpty || state.password.isEmpty) return;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.login(
      email: state.email,
      password: state.password,
    );

    result.fold(
      (failure) => state = state.copyWith(isLoading: false, error: failure),
      (user) {
        // 🔥 aquí conectas con la sesión
        ref.read(authSessionProvider.notifier).setAuthenticated(user);

        state = const LoginFormState(); // opcional: limpiar form
      },
    );
  }
}
