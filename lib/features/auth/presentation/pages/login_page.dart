import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_provider.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_state.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/widget/custom_login_text_form_field.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearErrorIfNeeded);
    _passwordController.addListener(_clearErrorIfNeeded);
  }

  void _clearErrorIfNeeded() {
    final authState = ref.read(authProvider);

    authState.maybeWhen(
      error: (failure) => ref.read(authProvider.notifier).clearError(),
      orElse: () {},
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLoginPressed() {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      return;
    }
    ref.read(authProvider.notifier).login(email: email, password: password);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    final isLoading = authState.maybeWhen(
      loading: () => true,
      orElse: () => false,
    );

    final errorMessage = authState.maybeWhen(
      error: (failure) => failure.when(
        invalidEmail: () => 'Correo inválido',
        wrongPassword: () => 'Contraseña Incorrecta',
        userNotFound: () => 'Usuario no encontrado',
        userDisabled: () => 'Usuario deshabilitado',
        networkError: () => 'Error de conexión',
        tooManyRequests: () => 'Demasiados intentos',
        unknown: () => 'Error inesperado',
      ),
      orElse: () => null,
    );

    return Scaffold(
      body: Container(
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
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400, maxHeight: 450),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/edicion-de-fotos.png',
                      width: 100,
                      height: 100,
                      cacheWidth: 110,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Monitor de Imagenes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomLoginTextFormField(
                      textController: _emailController,
                      labelText: 'email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 18),
                    CustomLoginTextFormField(
                      textController: _passwordController,
                      labelText: 'Contraseña',
                      obscureText: true,
                      onSubmit: _onLoginPressed,
                    ),

                    const SizedBox(height: 24),

                    if (errorMessage != null)
                      Column(
                        children: [
                          Text(
                            errorMessage,
                            style: TextStyle(color: AppColors.errorMessage),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                            EdgeInsets.symmetric(vertical: 20),
                          ),
                          backgroundColor: WidgetStateProperty.all<Color>(
                            AppColors.primaryGreen,
                          ),
                        ),
                        onPressed: isLoading ? null : _onLoginPressed,
                        child: isLoading
                            ? const CircularProgressIndicator(
                                color: AppColors.loadingColor,
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
    );
  }
}
