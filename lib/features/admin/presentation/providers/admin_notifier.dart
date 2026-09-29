import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/repositories/admin_repository.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

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
    final updatedUsers = [
      for (final u in state.users)
        if (u.uid == uid) u.copyWith(disabled: disabled) else u,
    ];

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
        // revertir (conservando el resto de campos, incluidos los roles)
        final revertedUsers = [
          for (final u in state.users)
            if (u.uid == uid) u.copyWith(disabled: !disabled) else u,
        ];
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
    final updatedUsers = [
      for (final u in state.users)
        if (u.uid == uid) u.copyWith(allowedGroups: allowedGroups) else u,
    ];

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

  Future<void> setUserRole({
    required String uid,
    required String role, // 'admin' | 'user'
  }) async {
    // Actualizar localmente para respuesta inmediata
    final updatedUsers = [
      for (final u in state.users)
        if (u.uid == uid) u.copyWith(isAdmin: role == 'admin') else u,
    ];

    state = state.copyWith(
      users: updatedUsers,
      isSubmitting: true,
      error: null,
    );

    final result = await _repository.setUserRole(uid: uid, role: role);

    result.fold(
      (failure) {
        state = state.copyWith(isSubmitting: false, error: failure);
        loadUsers(); // revertir recargando desde servidor
      },
      (_) => state = state.copyWith(
        isSubmitting: false,
        successMessage: role == 'admin'
            ? 'Usuario promovido a administrador'
            : 'Permisos de administrador removidos',
      ),
    );
  }

  /// Optimista para sentirse ágil, pero con una diferencia deliberada del
  /// patrón de `setUserRole`: cambiar de rol DE VERDAD limpia `reviewShifts`
  /// en el servidor (ver `setReviewRole` en `functions/index.js`), y el
  /// valor optimista de `reviewRole` por sí solo no refleja eso — sin
  /// recargar, la tarjeta mostraría horarios que ya no existen. Por eso
  /// SIEMPRE se recarga con `loadUsers()` al terminar, tanto en éxito como en
  /// fallo (a diferencia de `setUserRole`, que solo recarga si falla).
  Future<void> setReviewRole({
    required String uid,
    required ReviewRole? role,
  }) async {
    final updatedUsers = [
      for (final u in state.users)
        if (u.uid == uid) u.copyWith(reviewRole: role) else u,
    ];

    state = state.copyWith(
      users: updatedUsers,
      isSubmitting: true,
      error: null,
    );

    final result = await _repository.setReviewRole(uid: uid, role: role);

    result.fold(
      (failure) => state = state.copyWith(isSubmitting: false, error: failure),
      (_) => state = state.copyWith(
        isSubmitting: false,
        successMessage: role == null
            ? 'Rol de revisión removido'
            : 'Rol de revisión actualizado',
      ),
    );
    await loadUsers();
  }

  /// A diferencia de `setReviewRole`, NO es optimista: `updateReviewShifts`
  /// puede fallar por unicidad (otra persona del mismo rol ya cubre ese
  /// grupo+jornada), y mostrarle al superAdmin horarios que el servidor va a
  /// rechazar un instante después es peor que esperar el resultado. El
  /// usuario en el estado local NUNCA se toca a mano; siempre se recarga
  /// desde el servidor al terminar, tanto en éxito (refleja lo guardado)
  /// como en fallo (para que el resaltado de conflictos del diálogo quede al
  /// día en el siguiente intento). Devuelve el resultado además de
  /// actualizar `error`/`successMessage`, para que el diálogo que llama
  /// pueda reaccionar directamente (mantenerse abierto y mostrar el error)
  /// sin depender del snackbar global.
  Future<Either<AdminFailure, Unit>> updateReviewShifts({
    required String uid,
    required List<ReviewShift> shifts,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    final result = await _repository.updateReviewShifts(
      uid: uid,
      shifts: shifts,
    );

    result.fold(
      (failure) => state = state.copyWith(isSubmitting: false, error: failure),
      (_) => state = state.copyWith(
        isSubmitting: false,
        successMessage: 'Horarios actualizados',
      ),
    );
    await loadUsers();

    return result;
  }

  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}
