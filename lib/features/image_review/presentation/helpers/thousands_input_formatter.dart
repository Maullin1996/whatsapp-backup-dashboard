import 'dart:math' as math;

import 'package:flutter/services.dart';

/// Máximo de dígitos del total: evita desbordar el `int` al parsear.
const int maxTotalDigits = 12;

final RegExp _nonDigits = RegExp(r'\D');

/// Deja solo los dígitos de [text] (quita puntos, espacios, "$", etc.).
String onlyDigits(String text) => text.replaceAll(_nonDigits, '');

/// Agrega el punto de miles (es-CO) a una cadena de dígitos: `9000` -> `9.000`.
String formatThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Muestra el separador de miles mientras se escribe, pero el valor real son
/// solo los dígitos (quien lo use debe aplicar [onlyDigits] al texto).
///
/// - Pegar "9.000", "\$ 9000" o "9 000" deja "9.000".
/// - El tope [maxDigits] cuenta dígitos, no caracteres.
/// - El cursor se conserva contando los dígitos que quedan a su izquierda.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter({this.maxDigits = maxTotalDigits});

  final int maxDigits;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    var digits = onlyDigits(text);
    final oldDigits = onlyDigits(oldValue.text);
    final offset = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, text.length)
        : text.length;
    var digitsBeforeCursor = onlyDigits(text.substring(0, offset)).length;

    // Tecla escrita con el tope lleno: se ignora (como LengthLimiting).
    if (digits.length > maxDigits && oldDigits.length >= maxDigits) {
      if (digits.length == oldDigits.length + 1) return oldValue;
    }

    // Backspace sobre un punto: los dígitos no cambiaron, así que en vez de
    // quedarse trabado, se borra el dígito que está antes del punto.
    if (digits == oldDigits &&
        text.length < oldValue.text.length &&
        digitsBeforeCursor > 0) {
      digits =
          digits.substring(0, digitsBeforeCursor - 1) +
          digits.substring(digitsBeforeCursor);
      digitsBeforeCursor -= 1;
    }

    if (digits.length > maxDigits) digits = digits.substring(0, maxDigits);
    digitsBeforeCursor = math.min(digitsBeforeCursor, digits.length);

    final formatted = formatThousands(digits);
    var position = 0;
    var seen = 0;
    while (seen < digitsBeforeCursor) {
      if (formatted[position] != '.') seen++;
      position++;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: position),
    );
  }
}
