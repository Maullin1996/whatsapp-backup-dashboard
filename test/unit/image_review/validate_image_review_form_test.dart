import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/image_review_failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/helpers/validate_image_review_form.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

Comprobante _c({
  String codigo = 'A1',
  List<String> numeros = const ['5311'],
  int total = 9000,
}) => Comprobante(codigo: codigo, numeros: numeros, total: total);

ImageReviewFailure _failure(ImageReviewForm form) => validateImageReviewForm(
  form,
).fold((f) => f, (_) => fail('se esperaba un error'));

ImageReviewForm _ok(ImageReviewForm form) => validateImageReviewForm(
  form,
).fold((f) => fail('error inesperado: ${f.message}'), (v) => v);

void main() {
  group('validateImageReviewForm', () {
    test('formulario válido se devuelve normalizado', () {
      final form = ImageReviewForm(comprobantes: [_c()]);
      expect(_ok(form), form);
    });

    test('sin comprobantes -> sinComprobantes', () {
      expect(
        _failure(const ImageReviewForm(comprobantes: [])),
        const ImageReviewFailure.sinComprobantes(),
      );
    });

    group('código', () {
      test('vacío -> codigoVacio', () {
        expect(
          _failure(ImageReviewForm(comprobantes: [_c(codigo: '')])),
          const ImageReviewFailure.codigoVacio(1),
        );
      });

      test('solo espacios -> codigoVacio', () {
        expect(
          _failure(ImageReviewForm(comprobantes: [_c(codigo: '   ')])),
          const ImageReviewFailure.codigoVacio(1),
        );
      });

      test('se le aplica trim', () {
        final r = _ok(ImageReviewForm(comprobantes: [_c(codigo: '  A1 ')]));
        expect(r.comprobantes.single.codigo, 'A1');
      });

      test('el mismo código repetido es válido y no agrupa', () {
        final r = _ok(
          ImageReviewForm(
            comprobantes: [
              _c(codigo: 'A1', total: 9000),
              _c(codigo: 'A1', total: 3000),
            ],
          ),
        );
        expect(r.comprobantes, hasLength(2));
        expect(r.comprobantes.map((c) => c.total), [9000, 3000]);
      });
    });

    group('números', () {
      test('lista vacía -> comprobanteSinNumeros', () {
        expect(
          _failure(ImageReviewForm(comprobantes: [_c(numeros: const [])])),
          const ImageReviewFailure.comprobanteSinNumeros(1),
        );
      });

      test('solo vacíos/espacios -> comprobanteSinNumeros', () {
        expect(
          _failure(ImageReviewForm(comprobantes: [_c(numeros: ['', '  '])])),
          const ImageReviewFailure.comprobanteSinNumeros(1),
        );
      });

      test('trim y descarte de vacíos', () {
        final r = _ok(
          ImageReviewForm(
            comprobantes: [
              _c(numeros: [' 5311 ', '', '  ', '1111']),
            ],
          ),
        );
        expect(r.comprobantes.single.numeros, ['5311', '1111']);
      });

      test('conserva ceros a la izquierda', () {
        final r = _ok(
          ImageReviewForm(
            comprobantes: [
              _c(numeros: ['0123', '123']),
            ],
          ),
        );
        expect(r.comprobantes.single.numeros, ['0123', '123']);
      });
    });

    group('total', () {
      test('0 -> totalInvalido', () {
        expect(
          _failure(ImageReviewForm(comprobantes: [_c(total: 0)])),
          const ImageReviewFailure.totalInvalido(1),
        );
      });

      test('negativo -> totalInvalido', () {
        expect(
          _failure(ImageReviewForm(comprobantes: [_c(total: -500)])),
          const ImageReviewFailure.totalInvalido(1),
        );
      });

      test('1 es válido', () {
        _ok(ImageReviewForm(comprobantes: [_c(total: 1)]));
      });
    });

    group('orden e índice', () {
      test('reporta el índice (1-based) del comprobante con error', () {
        expect(
          _failure(ImageReviewForm(comprobantes: [_c(), _c(total: 0)])),
          const ImageReviewFailure.totalInvalido(2),
        );
      });

      test('por comprobante: código antes que números y total', () {
        expect(
          _failure(
            ImageReviewForm(
              comprobantes: [_c(codigo: '', numeros: const [], total: 0)],
            ),
          ),
          const ImageReviewFailure.codigoVacio(1),
        );
      });

      test('por comprobante: números antes que total', () {
        expect(
          _failure(
            ImageReviewForm(comprobantes: [_c(numeros: const [], total: 0)]),
          ),
          const ImageReviewFailure.comprobanteSinNumeros(1),
        );
      });

      test('fail-fast: un comprobante anterior con error gana', () {
        expect(
          _failure(
            ImageReviewForm(comprobantes: [_c(codigo: ''), _c(total: 0)]),
          ),
          const ImageReviewFailure.codigoVacio(1),
        );
      });
    });

    group('anotaciones', () {
      test('null se mantiene null', () {
        expect(_ok(ImageReviewForm(comprobantes: [_c()])).anotaciones, isNull);
      });

      test('vacías -> null', () {
        final r = _ok(ImageReviewForm(comprobantes: [_c()], anotaciones: ''));
        expect(r.anotaciones, isNull);
      });

      test('solo espacios -> null', () {
        final r = _ok(
          ImageReviewForm(comprobantes: [_c()], anotaciones: ' \n  '),
        );
        expect(r.anotaciones, isNull);
      });

      test('con texto se guardan con trim', () {
        final r = _ok(
          ImageReviewForm(comprobantes: [_c()], anotaciones: '  ilegible '),
        );
        expect(r.anotaciones, 'ilegible');
      });

      test('no afectan la validación', () {
        expect(
          validateImageReviewForm(
            const ImageReviewForm(comprobantes: [], anotaciones: 'nota'),
          ).isLeft(),
          isTrue,
        );
      });
    });
  });

  group('mapFailureToMessage con ImageReviewFailure', () {
    test('mensajes en español', () {
      expect(
        mapFailureToMessage(const ImageReviewFailure.sinComprobantes()),
        'Agrega al menos un comprobante',
      );
      expect(
        mapFailureToMessage(const ImageReviewFailure.codigoVacio(2)),
        'Comprobante 2: ingresa el código',
      );
      expect(
        mapFailureToMessage(const ImageReviewFailure.comprobanteSinNumeros(3)),
        'Comprobante 3: agrega al menos un número',
      );
      expect(
        mapFailureToMessage(const ImageReviewFailure.totalInvalido(1)),
        'Comprobante 1: el total debe ser mayor que 0',
      );
    });
  });
}
