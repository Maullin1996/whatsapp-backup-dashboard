import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/helpers/thousands_input_formatter.dart';

TextEditingValue _v(String text, [int? cursor]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: cursor ?? text.length),
);

void main() {
  const formatter = ThousandsInputFormatter();

  TextEditingValue apply(TextEditingValue old, TextEditingValue next) =>
      formatter.formatEditUpdate(old, next);

  void expectValue(TextEditingValue actual, String text, int cursor) {
    expect(actual.text, text);
    expect(actual.selection.baseOffset, cursor);
    expect(actual.selection.extentOffset, cursor);
  }

  group('formatThousands / onlyDigits', () {
    test('agrega el punto de miles', () {
      expect(formatThousands(''), '');
      expect(formatThousands('9'), '9');
      expect(formatThousands('900'), '900');
      expect(formatThousands('9000'), '9.000');
      expect(formatThousands('1234567'), '1.234.567');
    });

    test('onlyDigits quita todo lo que no es dígito', () {
      expect(onlyDigits('\$ 9.000'), '9000');
      expect(onlyDigits('9 000'), '9000');
      expect(onlyDigits('abc'), '');
    });
  });

  group('escribir', () {
    test('el primer dígito', () {
      expectValue(apply(_v(''), _v('9')), '9', 1);
    });

    test(
      'al llegar al cuarto dígito aparece el punto y el cursor lo cruza',
      () {
        expectValue(apply(_v('900'), _v('9000')), '9.000', 5);
      },
    );

    test('insertar en medio conserva el cursor tras el dígito escrito', () {
      // "1.234" con el cursor tras el "1"; se escribe "5".
      expectValue(apply(_v('1.234', 1), _v('15.234', 2)), '15.234', 2);
    });

    test('insertar que reagrupa los puntos mantiene el cursor', () {
      // "999" + "1" al principio -> "1.999", cursor tras el "1".
      expectValue(apply(_v('999', 0), _v('1999', 1)), '1.999', 1);
    });

    test('con el tope lleno, un dígito más se ignora', () {
      final full = _v('123.456.789.012');
      final result = apply(full, _v('123.456.789.0123'));
      expectValue(result, '123.456.789.012', 15);
    });
  });

  group('borrar', () {
    test('un dígito con Backspace', () {
      expectValue(apply(_v('9.000'), _v('9.00')), '900', 3);
    });

    test('Backspace justo después de un punto borra el dígito previo', () {
      // "9.000" con el cursor tras el punto (2); Backspace quita el ".".
      expectValue(apply(_v('9.000', 2), _v('9000', 1)), '000', 0);
    });

    test('borrar en medio conserva la posición', () {
      // "12.345", cursor tras el "3" (5) -> Backspace borra el "3".
      expectValue(apply(_v('12.345', 5), _v('12.45', 4)), '1.245', 4);
    });

    test('borrar todo deja el campo vacío', () {
      expectValue(apply(_v('9'), _v('')), '', 0);
    });
  });

  group('pegar', () {
    test('"9.000", "\$ 9000" y "9 000" dejan "9.000"', () {
      for (final pasted in ['9.000', '\$ 9000', '9 000']) {
        expectValue(apply(_v(''), _v(pasted)), '9.000', 5);
      }
    });

    test('el tope cuenta dígitos, no caracteres', () {
      // 12 dígitos con puntos (15 caracteres): entra completo.
      expectValue(apply(_v(''), _v('123.456.789.012')), '123.456.789.012', 15);
      // 13 dígitos: se recorta a 12.
      expectValue(apply(_v(''), _v('1234567890123')), '123.456.789.012', 15);
    });

    test('texto sin dígitos queda vacío', () {
      expectValue(apply(_v(''), _v('abc')), '', 0);
    });
  });
}
