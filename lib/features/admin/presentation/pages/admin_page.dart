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
      body: state.isLoadingUsers
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.loadingColor),
            )
          : state.users.isEmpty
          ? const Center(child: Text('No hay usuarios registrados'))
          : Center(
              child: ConstrainedBox(
                // En web limita el ancho máximo para que no se estire
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
                    Icons.person,
                    color: user.disabled ? Colors.grey : AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.email,
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 14,
                          color: Colors.black,
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
            // Grupos — en mobile se hace scroll horizontal si hay muchos
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
            // Acciones — en mobile se apilan, en web van en fila
            isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _actionButton(context, user),
                      const SizedBox(height: 4),
                      _groupsButton(context, user),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _actionButton(context, user),
                      const SizedBox(width: 8),
                      _groupsButton(context, user),
                    ],
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
}
