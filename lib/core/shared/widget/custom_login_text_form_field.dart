import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

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
    const border = OutlineInputBorder(
      borderRadius: AppRadius.dialogAll,
      borderSide: BorderSide(color: AppColors.inputBorder, width: 2),
    );
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
        fillColor: AppColors.inputBackground,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18),
        enabledBorder: border,
        focusedBorder: border,
        errorBorder: border,
        focusedErrorBorder: border,
      ),
      obscureText: obscureText,
    );
  }
}
