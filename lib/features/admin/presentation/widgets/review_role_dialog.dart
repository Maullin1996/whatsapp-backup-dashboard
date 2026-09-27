import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/review_role_radio_group.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Activa/cambia/desactiva el rol de revisión (Revisor, Sumador o Ninguno)
/// de una cuenta. Independiente de los horarios (grupo+jornada), que ahora
/// se editan por grupo desde `AssignGroupsDialog` ("Horarios").
///
/// Como `_roleButton` (Hacer admin/Quitar admin), no espera la respuesta del
/// servidor: `AdminNotifier.setReviewRole` es optimista y siempre recarga al
/// terminar, así que basta con dispararla y cerrar.
class ReviewRoleDialog extends ConsumerStatefulWidget {
  final AppUser user;
  const ReviewRoleDialog({super.key, required this.user});

  @override
  ConsumerState<ReviewRoleDialog> createState() => _ReviewRoleDialogState();
}

class _ReviewRoleDialogState extends ConsumerState<ReviewRoleDialog> {
  late ReviewRole? _role;

  @override
  void initState() {
    super.initState();
    _role = widget.user.reviewRole;
  }

  /// El servidor limpia `reviewShifts` cuando `reviewRole` cambia de verdad
  /// (ver `setReviewRole` en `functions/index.js`) — se advierte antes de
  /// confirmar si hay algo que perder.
  bool get _willClearShifts =>
      _role != widget.user.reviewRole && widget.user.reviewShifts.isNotEmpty;

  void _submit() {
    Navigator.of(context).pop();
    ref
        .read(adminProvider.notifier)
        .setReviewRole(uid: widget.user.uid, role: _role);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Rol de revisión',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.user.displayName,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: AppSpacing.sm),
            ReviewRoleRadioGroup(
              groupValue: _role,
              onChanged: (role) => setState(() => _role = role),
            ),
            if (_willClearShifts) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Esto borrará los ${widget.user.reviewShifts.length} '
                'horarios ya asignados a esta persona.',
                style: const TextStyle(
                  color: AppColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.green)),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
