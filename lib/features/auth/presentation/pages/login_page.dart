//login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/auth_failure.dart';
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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final horizontalPadding = isMobile ? 16.0 : 24.0;
    final cardPadding = isMobile ? 20.0 : 24.0;

    final errorMessage = formState.error?.message;

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
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
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
                    padding: EdgeInsets.all(cardPadding),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/edicion-de-fotos.png',
                          width: isMobile ? 84 : 100,
                          height: isMobile ? 84 : 100,
                        ),
                        SizedBox(height: isMobile ? 12 : 16),
                        Text(
                          'Monitor de Imagenes',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 20 : 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isMobile ? 20 : 24),

                        /// EMAIL
                        CustomTextFormField(
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
                        CustomTextFormField(
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
                            onPressed: formState.isLoading
                                ? null
                                : _onLoginPressed,
                            child: formState.isLoading
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
