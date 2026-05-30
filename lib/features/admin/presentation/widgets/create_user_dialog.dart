import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
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

    return ResponsiveLayout(
      mobile: _CreateUserDialogMobile(
        displayNameController: _displayNameController,
        passwordController: _passwordController,
        obscurePassword: _obscurePassword,
        isSubmitting: isSubmitting,
        onToggleObscure: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        onSubmit: _submit,
        onCancel: () => Navigator.of(context).pop(),
      ),
      desktop: _CreateUserDialogDesktop(
        displayNameController: _displayNameController,
        passwordController: _passwordController,
        obscurePassword: _obscurePassword,
        isSubmitting: isSubmitting,
        onToggleObscure: () =>
            setState(() => _obscurePassword = !_obscurePassword),
        onSubmit: _submit,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _CreateUserDialogMobile extends StatelessWidget {
  final TextEditingController displayNameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _CreateUserDialogMobile({
    required this.displayNameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crear usuario',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              CustomTextFormField(
                textController: displayNameController,
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
                textController: passwordController,
                obscureText: obscurePassword,
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting ? null : onCancel,
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
                    onPressed: isSubmitting ? null : onSubmit,
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

class _CreateUserDialogDesktop extends StatelessWidget {
  final TextEditingController displayNameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool isSubmitting;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _CreateUserDialogDesktop({
    required this.displayNameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.isSubmitting,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Crear usuario',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              CustomTextFormField(
                textController: displayNameController,
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
                textController: passwordController,
                obscureText: obscurePassword,
                labelText: 'Contraseña',
                prefixIcon: const Icon(Icons.lock_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: onToggleObscure,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting ? null : onCancel,
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
                    onPressed: isSubmitting ? null : onSubmit,
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
