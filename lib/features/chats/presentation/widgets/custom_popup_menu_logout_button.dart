//custom_popup_menu_logout_button.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';

class CustomPopupMenuLogoutButton extends ConsumerWidget {
  const CustomPopupMenuLogoutButton({super.key});

  void _onLogout(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(authSessionProvider.notifier).logout();

    messenger.showSnackBar(const SnackBar(content: Text('Sesión cerrada')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_ChatMenuAction>(
      position: PopupMenuPosition.under,
      color: Colors.white,
      icon: const Icon(CupertinoIcons.ellipsis_vertical),
      onSelected: (action) {
        switch (action) {
          case _ChatMenuAction.logout:
            _onLogout(context, ref);
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_ChatMenuAction>(
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
  const _HoverMenuItem({required this.icon, required this.text});

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

enum _ChatMenuAction { logout }
