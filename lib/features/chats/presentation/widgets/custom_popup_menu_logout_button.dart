//custom_popup_menu_logout_button.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authSessionProvider);
    final isAdmin = authState.maybeWhen(
      authenticated: (user) => user.isAdmin,
      orElse: () => false,
    );
    return PopupMenuButton<_ChatMenuAction>(
      position: PopupMenuPosition.under,
      color: Colors.white,
      icon: const Icon(CupertinoIcons.ellipsis_vertical),
      onSelected: (action) {
        switch (action) {
          case _ChatMenuAction.adminPanel:
            _onAdminPanel(context);
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
              isAdmin: true,
            ),
          ),
        const PopupMenuItem<_ChatMenuAction>(
          value: _ChatMenuAction.logout,
          padding: EdgeInsets.zero,
          child: _HoverMenuItem(
            icon: Icons.logout_rounded,
            text: 'Cerrar sesión',
          ),
        ),
      ],
    );
  }
}

class _HoverMenuItem extends StatefulWidget {
  final IconData icon;
  final String text;
  final bool isAdmin;
  const _HoverMenuItem({
    required this.icon,
    required this.text,
    this.isAdmin = false,
  });

  @override
  State<_HoverMenuItem> createState() => __HoverMenuItemState();
}

class __HoverMenuItemState extends State<_HoverMenuItem> {
  bool _isHovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: _isHovering ? Colors.red.withAlpha(30) : Colors.transparent,
        child: Row(
          children: [
            Icon(widget.icon, color: _isHovering ? Colors.red : Colors.black),
            const SizedBox(width: 8),
            Text(
              widget.text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _isHovering ? Colors.red : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChatMenuAction { logout, adminPanel }
