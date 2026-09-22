import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

class CustomMessageGroup extends StatelessWidget {
  const CustomMessageGroup({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 38, horizontal: AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.dialogAll,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Image.asset('assets/images/mensaje.png'),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Selecciona un grupo para continuar',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 28,
            ),
          ),
        ],
      ),
    );
  }
}
