import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_state.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/assign_groups_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/change_password_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/create_user_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/loading_widget.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';

import '../../../auth/presentation/providers/auth_providers.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;

    ref.listen(adminProvider, (_, next) {
      if (next.successMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: Colors.green,
          ),
        );
        ref.read(adminProvider.notifier).clearMessages();
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!.message),
            backgroundColor: Colors.red,
          ),
        );
        ref.read(adminProvider.notifier).clearMessages();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Panel de administración',
          style: TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 16 : 20,
          ),
        ),
        backgroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(adminProvider.notifier).loadUsers(),
          ),
        ],
      ),
      floatingActionButton: isMobile
          // En mobile: solo ícono
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              child: const Icon(Icons.person_add_rounded),
              onPressed: () => _showCreateDialog(context),
            )
          // En web/tablet: ícono + texto
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Nuevo usuario'),
              onPressed: () => _showCreateDialog(context),
            ),
      backgroundColor: Colors.white,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: state.isLoadingUsers
            ? KeyedSubtree(
                key: const ValueKey('loading'),
                child: Center(child: const LoadingWidget()),
              )
            : state.users.isEmpty
            ? KeyedSubtree(
                key: const ValueKey('empty'),
                child: const Center(child: Text('No hay usuarios registrados')),
              )
            : KeyedSubtree(
                key: const ValueKey('users'),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: ListView.separated(
                      padding: EdgeInsets.all(isMobile ? 12 : 24),
                      itemCount: state.users.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: isMobile ? 8 : 12),
                      itemBuilder: (context, index) {
                        final user = state.users[index];
                        return _UserCard(
                          user: user,
                          state: state,
                          isMobile: isMobile,
                        );
                      },
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const CreateUserDialog());
  }
}

class _UserCard extends ConsumerWidget {
  final AppUser user;
  final AdminState state;
  final bool isMobile;

  const _UserCard({
    required this.user,
    required this.state,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);
    final isSuperAdmin = authState.maybeWhen(
      authenticated: (user) => user.isSuperAdmin,
      orElse: () => false,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: const Color.fromARGB(255, 246, 246, 246),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 10 : 12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isMobile ? 20 : 24,
                  backgroundColor: user.disabled
                      ? Colors.grey.shade300
                      : AppColors.primaryGreen.withAlpha(40),
                  child: Icon(
                    // ← mostrar ícono de admin si corresponde
                    user.isAdmin
                        ? Icons.admin_panel_settings_rounded
                        : Icons.person,
                    color: user.disabled ? Colors.grey : AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectionArea(
                        child: Text(
                          user.email,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // ← badge de rol
                      if (user.isSuperAdmin)
                        Text(
                          'SuperAdmin',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.purple,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (user.isAdmin)
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: !user.disabled,
                  activeThumbColor: AppColors.primaryGreen,
                  onChanged: state.isSubmitting
                      ? null
                      : (value) => ref
                            .read(adminProvider.notifier)
                            .toggleUserStatus(uid: user.uid, disabled: !value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: user.allowedGroups.isEmpty
                    ? [
                        Chip(
                          label: const Text('Sin grupos'),
                          backgroundColor: Colors.grey.shade100,
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ]
                    : user.allowedGroups.map((g) {
                        final group = state.groups
                            .where((gr) => gr.chatJid == g)
                            .firstOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Chip(
                            label: Text(group?.groupName ?? g),
                            backgroundColor: AppColors.primaryGreen.withAlpha(
                              30,
                            ),
                            labelStyle: const TextStyle(fontSize: 11),
                          ),
                        );
                      }).toList(),
              ),
            ),
            const SizedBox(height: 4),
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _actionButton(context, user),
                      const SizedBox(height: 4),
                      _groupsButton(context, user),
                      // ← botón de rol solo para superAdmin y no sobre sí mismo
                      if (isSuperAdmin && !user.isSuperAdmin) ...[
                        const SizedBox(height: 4),
                        _roleButton(context, user, ref),
                      ],
                      if (!user.isSuperAdmin) ...[
                        const SizedBox(height: 4),
                        _deleteButton(context, user, ref),
                      ],
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _actionButton(context, user),
                      const SizedBox(width: 8),
                      _groupsButton(context, user),
                      if (isSuperAdmin && !user.isSuperAdmin) ...[
                        const SizedBox(width: 8),
                        _roleButton(context, user, ref),
                      ],
                      if (!user.isSuperAdmin) ...[
                        const SizedBox(width: 8),
                        _deleteButton(context, user, ref),
                      ],
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // ← nuevo botón
  Widget _roleButton(BuildContext context, AppUser user, WidgetRef ref) {
    final isAdmin = user.isAdmin;
    return TextButton.icon(
      icon: Icon(
        isAdmin
            ? Icons.person_remove_rounded
            : Icons.admin_panel_settings_rounded,
        size: 18,
        color: isAdmin ? Colors.orange : Colors.purple,
      ),
      label: Text(
        isAdmin ? 'Quitar admin' : 'Hacer admin',
        style: TextStyle(
          color: isAdmin ? Colors.orange : Colors.purple,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isAdmin ? '¿Quitar permisos de admin?' : '¿Hacer administrador?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              isAdmin
                  ? '${user.displayName} perderá acceso al panel de administración.'
                  : '${user.displayName} podrá gestionar usuarios y grupos.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.green),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isAdmin ? Colors.orange : Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ref
                    .read(adminProvider.notifier)
                    .setUserRole(
                      uid: user.uid,
                      role: isAdmin ? 'user' : 'admin',
                    );
              },
              child: Text(isAdmin ? 'Quitar admin' : 'Hacer admin'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, AppUser user) {
    return TextButton.icon(
      icon: const Icon(
        Icons.lock_reset_rounded,
        size: 18,
        color: AppColors.loadingColor,
      ),
      label: const Text(
        'Cambiar contraseña',
        style: TextStyle(
          color: AppColors.loadingColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () => showDialog(
        context: context,
        builder: (_) => ChangePasswordDialog(uid: user.uid),
      ),
    );
  }

  Widget _groupsButton(BuildContext context, AppUser user) {
    return TextButton.icon(
      icon: const Icon(
        Icons.group_rounded,
        size: 18,
        color: AppColors.loadingColor,
      ),
      label: const Text(
        'Asignar grupos',
        style: TextStyle(
          color: AppColors.loadingColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      onPressed: () => showDialog(
        context: context,
        builder: (_) => AssignGroupsDialog(user: user),
      ),
    );
  }

  Widget _deleteButton(BuildContext context, AppUser user, WidgetRef ref) {
    return TextButton.icon(
      icon: const Icon(Icons.delete_rounded, size: 18, color: Colors.red),
      label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
      onPressed: () => showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            '¿Eliminar usuario?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Text(
              'Esta acción eliminará permanentemente a ${user.displayName} (${user.email}). No se puede deshacer.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.green),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                ref.read(adminProvider.notifier).deleteUser(uid: user.uid);
              },
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    );
  }
}
