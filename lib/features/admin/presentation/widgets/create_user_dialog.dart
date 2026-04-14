import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/shared/widget/custom_login_text_form_field.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';

class CreateUserDialog extends ConsumerStatefulWidget {
  const CreateUserDialog({super.key});

  @override
  ConsumerState<CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends ConsumerState<CreateUserDialog> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = "${_displayNameController.text.trim()}@gmail.com";
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();
    if (email.isEmpty || password.isEmpty || displayName.isEmpty) return;

    await ref
        .read(adminProvider.notifier)
        .createUser(email: email, password: password, displayName: displayName);

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(adminProvider).isSubmitting;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      // En mobile ocupa casi todo el ancho, en web se limita
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 80,
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
                'Crear usuario',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 20,
                  color: Colors.green,
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              CustomTextFormField(
                textController: _displayNameController,
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_rounded),
              ),
              const SizedBox(height: 12),
              // CustomTextFormField(
              //   textController: _emailController,
              //   keyboardType: TextInputType.emailAddress,
              //   labelText: 'Correo',
              //   prefixIcon: Icon(Icons.email_rounded),
              // ),
              const SizedBox(height: 12),
              CustomTextFormField(
                textController: _passwordController,
                obscureText: _obscurePassword,
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_rounded),
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
                      style: TextStyle(color: AppColors.loadingColor),
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
                        : const Text('Crear'),
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
