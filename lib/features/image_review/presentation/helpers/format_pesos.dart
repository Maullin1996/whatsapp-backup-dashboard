/// Formatea un monto en pesos sin decimales con punto de miles (es-CO):
/// `9000` -> `$9.000`.
String formatPesos(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}\$$buffer';
}
