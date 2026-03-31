import 'package:flutter/material.dart';

class NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const NavButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 32),
        ),
      ),
    );
  }
}
