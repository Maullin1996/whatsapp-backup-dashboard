import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';

/// Selector exclusivo Ninguno/Revisor/Sumador, extraído del extinto
/// `ReviewAssignmentDialog` (que combinaba esto con grupo+jornada en un solo
/// diálogo, modelo reemplazado por uno de lista — ver
/// `.claude/skills/image-review-roles.md`). Reutilizado por `ReviewRoleDialog`.
class ReviewRoleRadioGroup extends StatelessWidget {
  final ReviewRole? groupValue;
  final ValueChanged<ReviewRole?> onChanged;

  const ReviewRoleRadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioGroup<ReviewRole?>(
      groupValue: groupValue,
      onChanged: onChanged,
      child: Column(
        children: [
          const _RoleRadio(label: 'Ninguno', value: null),
          _RoleRadio(
            label: ReviewRole.revisor.label,
            value: ReviewRole.revisor,
          ),
          _RoleRadio(
            label: ReviewRole.sumador.label,
            value: ReviewRole.sumador,
          ),
        ],
      ),
    );
  }
}

/// Una opción de rol. Sin `groupValue`/`onChanged` propios: los toma del
/// [RadioGroup] ancestro (API no deprecada desde Flutter 3.32).
class _RoleRadio extends StatelessWidget {
  final String label;
  final ReviewRole? value;

  const _RoleRadio({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ReviewRole?>(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      activeColor: AppColors.primaryGreen,
    );
  }
}
