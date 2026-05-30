//login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/core/shared/widget/custom_login_text_form_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isPasswordVisible = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    FocusScope.of(context).unfocus();
    setState(() => _isPasswordVisible = false);

    ref.read(loginFormProvider.notifier).submit();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(loginFormProvider, (previous, next) {
      if (!next.isLoading &&
          previous?.isLoading == true &&
          next.error == null) {
        _emailController.clear();
        _passwordController.clear();
      }
    });

    final formState = ref.watch(loginFormProvider);
    final errorMessage = formState.error?.message;

    return ResponsiveLayout(
      mobile: _LoginPageMobile(
        emailController: _emailController,
        passwordController: _passwordController,
        isPasswordVisible: _isPasswordVisible,
        isLoading: formState.isLoading,
        errorMessage: errorMessage,
        onLoginPressed: _onLoginPressed,
        onTogglePasswordVisibility: () =>
            setState(() => _isPasswordVisible = !_isPasswordVisible),
        onEmailChanged: (value) =>
            ref.read(loginFormProvider.notifier).onEmailChanged(value),
        onPasswordChanged: (value) =>
            ref.read(loginFormProvider.notifier).onPasswordChanged(value),
      ),
      desktop: _LoginPageDesktop(
        emailController: _emailController,
        passwordController: _passwordController,
        isPasswordVisible: _isPasswordVisible,
        isLoading: formState.isLoading,
        errorMessage: errorMessage,
        onLoginPressed: _onLoginPressed,
        onTogglePasswordVisibility: () =>
            setState(() => _isPasswordVisible = !_isPasswordVisible),
        onEmailChanged: (value) =>
            ref.read(loginFormProvider.notifier).onEmailChanged(value),
        onPasswordChanged: (value) =>
            ref.read(loginFormProvider.notifier).onPasswordChanged(value),
      ),
    );
  }
}

class _LoginPageMobile extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onLoginPressed;
  final VoidCallback onTogglePasswordVisibility;
  final void Function(String) onEmailChanged;
  final void Function(String) onPasswordChanged;

  const _LoginPageMobile({
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.isLoading,
    required this.errorMessage,
    required this.onLoginPressed,
    required this.onTogglePasswordVisibility,
    required this.onEmailChanged,
    required this.onPasswordChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.upLoginBackground,
                AppColors.downLoginBackground,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                        spreadRadius: 5,
                      ),
                    ],
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/edicion-de-fotos.png',
                          width: 84,
                          height: 84,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Monitor de Imagenes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),

                        /// EMAIL
                        CustomTextFormField(
                          textController: emailController,
                          labelText: 'email',
                          keyboardType: TextInputType.emailAddress,
                          onChanged: onEmailChanged,
                        ),

                        const SizedBox(height: 18),

                        /// PASSWORD
                        CustomTextFormField(
                          textController: passwordController,
                          autocorrect: false,
                          enableSuggestions: false,
                          labelText: 'Contraseña',
                          obscureText: !isPasswordVisible,
                          onSubmit: onLoginPressed,
                          onChanged: onPasswordChanged,
                          suffixIcon: IconButton(
                            onPressed: onTogglePasswordVisibility,
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// ERROR
                        if (errorMessage != null)
                          Column(
                            children: [
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.errorMessage),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        /// BOTÓN
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              minimumSize: WidgetStateProperty.all<Size>(
                                const Size.fromHeight(56),
                              ),
                              padding:
                                  WidgetStateProperty.all<EdgeInsetsGeometry>(
                                    const EdgeInsets.symmetric(vertical: 16),
                                  ),
                              backgroundColor: WidgetStateProperty.all<Color>(
                                AppColors.primaryGreen,
                              ),
                            ),
                            onPressed: isLoading ? null : onLoginPressed,
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.loadingColor,
                                    ),
                                  )
                                : const Text(
                                    'Ingresar',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginPageDesktop extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isPasswordVisible;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onLoginPressed;
  final VoidCallback onTogglePasswordVisibility;
  final void Function(String) onEmailChanged;
  final void Function(String) onPasswordChanged;

  const _LoginPageDesktop({
    required this.emailController,
    required this.passwordController,
    required this.isPasswordVisible,
    required this.isLoading,
    required this.errorMessage,
    required this.onLoginPressed,
    required this.onTogglePasswordVisibility,
    required this.onEmailChanged,
    required this.onPasswordChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.upLoginBackground,
                AppColors.downLoginBackground,
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                        spreadRadius: 5,
                      ),
                    ],
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/edicion-de-fotos.png',
                          width: 100,
                          height: 100,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Monitor de Imagenes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),

                        /// EMAIL
                        CustomTextFormField(
                          textController: emailController,
                          labelText: 'email',
                          keyboardType: TextInputType.emailAddress,
                          onChanged: onEmailChanged,
                        ),

                        const SizedBox(height: 18),

                        /// PASSWORD
                        CustomTextFormField(
                          textController: passwordController,
                          autocorrect: false,
                          enableSuggestions: false,
                          labelText: 'Contraseña',
                          obscureText: !isPasswordVisible,
                          onSubmit: onLoginPressed,
                          onChanged: onPasswordChanged,
                          suffixIcon: IconButton(
                            onPressed: onTogglePasswordVisibility,
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        /// ERROR
                        if (errorMessage != null)
                          Column(
                            children: [
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.errorMessage),
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),

                        /// BOTÓN
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              minimumSize: WidgetStateProperty.all<Size>(
                                const Size.fromHeight(56),
                              ),
                              padding:
                                  WidgetStateProperty.all<EdgeInsetsGeometry>(
                                    const EdgeInsets.symmetric(vertical: 16),
                                  ),
                              backgroundColor: WidgetStateProperty.all<Color>(
                                AppColors.primaryGreen,
                              ),
                            ),
                            onPressed: isLoading ? null : onLoginPressed,
                            child: isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: AppColors.loadingColor,
                                    ),
                                  )
                                : const Text(
                                    'Ingresar',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
