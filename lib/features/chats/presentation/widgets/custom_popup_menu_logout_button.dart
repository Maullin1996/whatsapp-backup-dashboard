//custom_popup_menu_logout_button.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';

class CustomPopupMenuLogoutButton extends ConsumerWidget {
  const CustomPopupMenuLogoutButton({super.key});

  void _onLogout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authSessionProvider.notifier).logout();

    messenger.showSnackBar(const SnackBar(content: Text('Sesión cerrada')));
  }

  void _onAdminPanel(BuildContext context) {
    context.push('/admin');
  }

  void _onSummary(BuildContext context) {
    context.push('/summary');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);
    final isAdmin = authState.maybeWhen(
      authenticated: (user) => user.isAdmin,
      orElse: () => false,
    );
    return PopupMenuButton<_ChatMenuAction>(
      position: PopupMenuPosition.under,
      icon: const Icon(CupertinoIcons.ellipsis_vertical),
      onSelected: (action) {
        switch (action) {
          case _ChatMenuAction.adminPanel:
            _onAdminPanel(context);
            break;
          case _ChatMenuAction.summary:
            _onSummary(context);
            break;
          case _ChatMenuAction.logout:
            _onLogout(context, ref);
            break;
        }
      },
      itemBuilder: (context) => [
        if (isAdmin)
          const PopupMenuItem<_ChatMenuAction>(
            value: _ChatMenuAction.adminPanel,
            padding: EdgeInsets.zero,
            child: _HoverMenuItem(
              icon: Icons.admin_panel_settings_rounded,
              text: 'Panel de administración',
            ),
          ),
        // Visible para cualquier usuario autenticado: no hay claims reales de
        // revisor/sumador todavía (ver la ruta `/summary` en router.dart).
        const PopupMenuItem<_ChatMenuAction>(
          value: _ChatMenuAction.summary,
          padding: EdgeInsets.zero,
          child: _HoverMenuItem(
            icon: Icons.fact_check_rounded,
            text: 'Resumen',
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<_ChatMenuAction>(
          value: _ChatMenuAction.logout,
          padding: EdgeInsets.zero,
          child: _HoverMenuItem(
            icon: Icons.logout_rounded,
            text: 'Cerrar sesión',
            isDestructive: true,
          ),
        ),
      ],
    );
  }
}

/// Item del menú con resalte al pasar el mouse. El resalte es del acento verde
/// de la app, salvo en acciones destructivas ([isDestructive]), que van en rojo.
class _HoverMenuItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final bool isDestructive;
  const _HoverMenuItem({
    required this.icon,
    required this.text,
    this.isDestructive = false,
  });

  @override
  State<_HoverMenuItem> createState() => __HoverMenuItemState();
}

class __HoverMenuItemState extends State<_HoverMenuItem> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isDestructive
        ? AppColors.errorMessage
        : AppColors.primaryGreen;
    final color = _isHovering
        ? accent
        : Theme.of(context).colorScheme.onSurface;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: _isHovering
            ? accent.withValues(alpha: 0.12)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(widget.icon, color: color),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                widget.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatMenuAction { logout, adminPanel, summary }
