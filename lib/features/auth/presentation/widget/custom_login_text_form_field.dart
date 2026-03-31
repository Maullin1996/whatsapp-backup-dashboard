import 'package:flutter/material.dart';

class CustomLoginTextFormField extends StatelessWidget {
  final TextEditingController textController;
  final TextInputType? keyboardType;
  final String labelText;
  final VoidCallback? onSubmit;
  final bool obscureText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final bool enableSuggestions;
  final bool autocorrect;
  const CustomLoginTextFormField({
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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color.fromARGB(96, 236, 248, 240),
        border: Border.all(
          color: const Color.fromARGB(255, 167, 231, 200),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextFormField(
        onChanged: onChanged,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        controller: textController,
        textInputAction: TextInputAction.done,
        keyboardType: keyboardType,
        onFieldSubmitted: (_) => onSubmit?.call(),
        decoration: InputDecoration(
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          labelText: labelText,
          floatingLabelStyle: TextStyle(color: Colors.black),
        ),
        obscureText: obscureText,
      ),
    );
  }
}
