import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/repositories/admin_repository.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_state.dart';

class AdminNotifier extends Notifier<AdminState> {
  late final AdminRepository _repository;
  @override
  AdminState build() {
    _repository = ref.read(adminRepositoryProvider);
    Future.microtask(() {
      loadUsers();
      loadGroups();
    });
    return const AdminState(isLoadingUsers: true, isLoadingGroups: true);
  }

  Future<void> loadUsers() async {
    // Solo mostrar loading si no hay usuarios previos
    if (state.users.isEmpty) {
      state = state.copyWith(isLoadingUsers: true, error: null);
    }
    final result = await _repository.listUsers();
    result.fold(
      (failure) =>
          state = state.copyWith(isLoadingUsers: false, error: failure),
      (users) => state = state.copyWith(isLoadingUsers: false, users: users),
    );
  }

  Future<void> loadGroups() async {
    state = state.copyWith(isLoadingGroups: true, error: null);
    final result = await _repository.listGroups();
    result.fold(
      (failure) =>
          state = state.copyWith(isLoadingGroups: false, error: failure),
      (groups) =>
          state = state.copyWith(isLoadingGroups: false, groups: groups),
    );
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      error: null,
      successMessage: null,
    );
    final result = await _repository.createUser(
      email: email,
      password: password,
      displayName: displayName,
    );

    result.fold(
      (failure) => state = state.copyWith(isSubmitting: false, error: failure),
      (user) => state = state.copyWith(
        isSubmitting: false,
        users: [...state.users, user],
        successMessage: 'Usuario creado exitosamente',
      ),
    );
  }

  Future<void> deleteUser({required String uid}) async {
    final updatedUsers = state.users.where((u) => u.uid != uid).toList();
    state = state.copyWith(
      users: updatedUsers,
      isSubmitting: true,
      error: null,
    );

    final result = await _repository.deleteUser(uid: uid);

    result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure);
        loadUsers();
      },
      (_) => state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Usuario eliminado',
      ),
    );
  }

  Future<void> updatePassword({
    required String uid,
    required String newPassword,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      error: null,
      successMessage: null,
    );
    final result = await _repository.updatePassword(
      uid: uid,
      newPassword: newPassword,
    );
    result.fold(
      (failure) => state = state.copyWith(isSubmitting: false, error: failure),
      (_) => state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Contraseña actualizada',
      ),
    );
  }

  Future<void> toggleUserStatus({
    required String uid,
    required bool disabled,
  }) async {
    // Actualizar localmente ANTES de llamar a la función para respuesta inmediata
    final updatedUsers = state.users.map((u) {
      if (u.uid != uid) return u;
      return AppUser(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        disabled: disabled,
        allowedGroups: u.allowedGroups,
      );
    }).toList();

    state = state.copyWith(
      users: updatedUsers,
      isSubmitting: true,
      error: null,
    );

    final result = await _repository.toggleUserStatus(
      uid: uid,
      disabled: disabled,
    );

    result.fold(
      (failure) {
        // Si falla, revertir el cambio local
        final revertedUsers = state.users.map((u) {
          if (u.uid != uid) return u;
          return AppUser(
            uid: u.uid,
            email: u.email,
            displayName: u.displayName,
            disabled: !disabled, // revertir
            allowedGroups: u.allowedGroups,
          );
        }).toList();
        state = state.copyWith(
          isSubmitting: false,
          users: revertedUsers,
          error: failure,
        );
      },
      (_) => state = state.copyWith(
        isSubmitting: false,
        successMessage: disabled
            ? 'Usuario deshabilitado'
            : 'Usuario habilitado',
      ),
    );
  }

  Future<void> updateUserGroups({
    required String uid,
    required List<String> allowedGroups,
  }) async {
    // Actualizar localmente ANTES para respuesta inmediata
    final updatedUsers = state.users.map((u) {
      if (u.uid != uid) return u;
      return AppUser(
        uid: u.uid,
        email: u.email,
        displayName: u.displayName,
        disabled: u.disabled,
        allowedGroups: allowedGroups,
      );
    }).toList();

    state = state.copyWith(
      users: updatedUsers,
      isSubmitting: true,
      error: null,
    );

    final result = await _repository.updateUserGroups(
      uid: uid,
      allowedGroups: allowedGroups,
    );

    result.fold(
      (failure) {
        // Si falla, recargar desde el servidor para tener el estado real
        state = state.copyWith(isSubmitting: false, error: failure);
        loadUsers();
      },
      (_) => state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Grupos actualizados',
      ),
    );
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}
