import 'package:flutter/material.dart';

class CustomTextFormField extends StatelessWidget {
  final TextEditingController textController;
  final TextInputType? keyboardType;
  final String labelText;
  final VoidCallback? onSubmit;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool enableSuggestions;
  final bool autocorrect;
  final Widget? prefixIcon;
  final bool autofocus;

  const CustomTextFormField({
    super.key,
    required this.textController,
    this.keyboardType,
    required this.labelText,
    this.obscureText = false,
    this.onSubmit,
    this.suffixIcon,
    this.onChanged,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.prefixIcon,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      autofocus: autofocus,
      onChanged: onChanged,
      enableSuggestions: enableSuggestions,
      autocorrect: autocorrect,
      controller: textController,
      textInputAction: TextInputAction.done,
      keyboardType: keyboardType,
      onFieldSubmitted: (_) => onSubmit?.call(),
      decoration: InputDecoration(
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        labelText: labelText,
        floatingLabelStyle: const TextStyle(color: Colors.black),
        filled: true,
        fillColor: const Color.fromARGB(96, 236, 248, 240),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 167, 231, 200),
            width: 2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 167, 231, 200),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 167, 231, 200),
            width: 2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 167, 231, 200),
            width: 2,
          ),
        ),
      ),
      obscureText: obscureText,
    );
  }
}
