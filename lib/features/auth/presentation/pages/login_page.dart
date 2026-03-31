//login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/widget/custom_login_text_form_field.dart';

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

    final errorMessage = formState.error?.when(
      invalidEmail: () => 'Correo inválido',
      wrongPassword: () => 'Contraseña Incorrecta',
      userNotFound: () => 'Usuario no encontrado',
      userDisabled: () => 'Usuario deshabilitado',
      networkError: () => 'Error de conexión',
      tooManyRequests: () => 'Demasiados intentos',
      unknown: () => 'Error inesperado',
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

                    /// EMAIL
                    CustomLoginTextFormField(
                      textController: _emailController,
                      labelText: 'email',
                      keyboardType: TextInputType.emailAddress,
                      onChanged: (value) {
                        ref
                            .read(loginFormProvider.notifier)
                            .onEmailChanged(value);
                      },
                    ),

                    const SizedBox(height: 18),

                    /// PASSWORD
                    CustomLoginTextFormField(
                      textController: _passwordController,
                      autocorrect: false,
                      enableSuggestions: false,
                      labelText: 'Contraseña',
                      obscureText: !_isPasswordVisible,
                      onSubmit: _onLoginPressed,
                      onChanged: (value) {
                        ref
                            .read(loginFormProvider.notifier)
                            .onPasswordChanged(value);
                      },
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                        icon: Icon(
                          _isPasswordVisible
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
                            errorMessage,
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
                          padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
                            EdgeInsets.symmetric(vertical: 20),
                          ),
                          backgroundColor: WidgetStateProperty.all<Color>(
                            AppColors.primaryGreen,
                          ),
                        ),
                        onPressed: formState.isLoading ? null : _onLoginPressed,
                        child: formState.isLoading
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
