//auth_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/repositories/auth_repository.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/chats_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';

class AuthSessionNotifier extends Notifier<AuthSessionState> {
  late final AuthRepository _repository;

  @override
  AuthSessionState build() {
    _repository = ref.read(authRepositoryProvider);
    _loadSession();
    return const AuthSessionState.loading();
  }

  Future<void> _loadSession() async {
    //ref.read(activeChatProvider.notifier).clear();
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
    ref.read(chatsProvider.notifier).cancelStream();
    ref.read(messagesProvider.notifier).cancelStream();
    ref.read(activeChatProvider.notifier).clear();
    await _repository.logout();
    state = const AuthSessionState.unauthenticated();
    ref.invalidate(chatsProvider);
  }

  void setAuthenticated(AuthenticatedUser user) {
    state = AuthSessionState.authenticated(user);
    ref.invalidate(chatsProvider);
    ref.read(activeChatProvider.notifier).clear();
  }
}
