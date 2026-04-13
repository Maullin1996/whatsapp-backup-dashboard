import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/shared/widget/custom_login_text_form_field.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';

class ChangePasswordDialog extends ConsumerStatefulWidget {
  final String uid;
  const ChangePasswordDialog({super.key, required this.uid});

  @override
  ConsumerState<ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<ChangePasswordDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPassword = _passwordController.text.trim();
    if (newPassword.isEmpty) return;

    await ref
        .read(adminProvider.notifier)
        .updatePassword(uid: widget.uid, newPassword: newPassword);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(adminProvider).isSubmitting;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 120,
        vertical: 24,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cambiar contraseña',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 20,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              CustomTextFormField(
                textController: _passwordController,
                obscureText: _obscurePassword,
                autofocus: true,
                labelText: 'Nueva contraseña',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(90, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isSubmitting ? null : _submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
