import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/image_review_failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/helpers/validate_image_review_form.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

// Ajuste (lotería obligatoria de lista cerrada): antes la lotería era texto
// libre y opcional, y `_c` la dejaba en null. Ahora todo comprobante necesita
// una lotería de la lista, así que `_c` usa una por defecto; los casos que
// prueban otra cosa (código, números, total, anotaciones...) no cambian.
const _loteria = 'dorado_tarde';

Comprobante _c({
  List<String> numeros = const ['5311'],
  int total = 9000,
  String? loteria = _loteria,
}) => Comprobante(numeros: numeros, total: total, loteria: loteria);

/// Formulario con el código de la imagen ya puesto (salvo que se pase otro).
ImageReviewForm _form(
  List<Comprobante> comprobantes, {
  String? codigo = 'A1',
  String? anotaciones,
}) => ImageReviewForm(
  codigo: codigo,
  comprobantes: comprobantes,
  anotaciones: anotaciones,
);

ImageReviewFailure _failure(
  ImageReviewForm form, [
  ReviewRole rol = ReviewRole.revisor,
]) => validateImageReviewForm(
  form,
  rol,
).fold((f) => f, (_) => fail('se esperaba un error'));

ImageReviewForm _ok(
  ImageReviewForm form, [
  ReviewRole rol = ReviewRole.revisor,
]) => validateImageReviewForm(
  form,
  rol,
).fold((f) => fail('error inesperado: ${f.message}'), (v) => v);

void main() {
  group('validateImageReviewForm', () {
    test('formulario válido se devuelve normalizado', () {
      final form = _form([_c()]);
      expect(_ok(form), form);
    });

    test('sin comprobantes -> sinComprobantes', () {
      expect(
        _failure(_form(const [])),
        const ImageReviewFailure.sinComprobantes(),
      );
    });

    group('código de la imagen (uno por foto)', () {
      test('ausente (null) -> codigoVacio', () {
        expect(
          _failure(_form([_c()], codigo: null)),
          const ImageReviewFailure.codigoVacio(),
        );
      });

      test('vacío -> codigoVacio', () {
        expect(
          _failure(_form([_c()], codigo: '')),
          const ImageReviewFailure.codigoVacio(),
        );
      });

      test('solo espacios -> codigoVacio', () {
        expect(
          _failure(_form([_c()], codigo: '   ')),
          const ImageReviewFailure.codigoVacio(),
        );
      });

      test('se le aplica trim', () {
        final r = _ok(_form([_c()], codigo: '  A1 '));
        expect(r.codigo, 'A1');
      });

      test('conserva ceros a la izquierda, mayúsculas y tildes', () {
        expect(_ok(_form([_c()], codigo: '0457')).codigo, '0457');
        expect(_ok(_form([_c()], codigo: 'Antioquía')).codigo, 'Antioquía');
      });

      test('el comprobante ya no lleva código: sin código propio no da '
          'error', () {
        final r = _ok(_form([_c(), _c(total: 3000)]));
        expect(r.comprobantes, hasLength(2));
      });

      test('vale para todos los comprobantes: no los agrupa ni los suma', () {
        final r = _ok(_form([_c(total: 9000), _c(total: 3000)]));
        expect(r.comprobantes.map((c) => c.total), [9000, 3000]);
      });
    });

    group('lotería (por comprobante, obligatoria, lista cerrada)', () {
      test('sin lotería (null) -> loteriaInvalida', () {
        expect(
          _failure(_form([_c(loteria: null)])),
          const ImageReviewFailure.loteriaInvalida(1),
        );
      });

      test('vacía o en blanco -> loteriaInvalida', () {
        for (final blank in ['', '   ', ' \n ']) {
          expect(
            _failure(_form([_c(loteria: blank)])),
            const ImageReviewFailure.loteriaInvalida(1),
            reason: '"$blank"',
          );
        }
      });

      test('fuera de la lista -> loteriaInvalida (texto libre, nombre en vez '
          'del identificador, otra escritura, espacios)', () {
        for (final fuera in [
          'baloto',
          'Lotería de Medellín',
          'Medellín',
          'MEDELLIN',
          ' medellin',
          'dorado tarde',
          'dorado_tarde ',
        ]) {
          expect(
            _failure(_form([_c(loteria: fuera)])),
            const ImageReviewFailure.loteriaInvalida(1),
            reason: '"$fuera"',
          );
        }
      });

      test('una de la lista pasa y se guarda el identificador tal cual', () {
        expect(
          _ok(_form([_c(loteria: 'medellin')])).comprobantes.single.loteria,
          'medellin',
        );
      });

      test('cada comprobante se valida por separado', () {
        expect(
          _failure(_form([_c(), _c(loteria: null)])),
          const ImageReviewFailure.loteriaInvalida(2),
        );
        expect(
          _failure(_form([_c(loteria: 'baloto'), _c()])),
          const ImageReviewFailure.loteriaInvalida(1),
        );
      });

      test('distinta entre comprobantes de la misma foto', () {
        final r = _ok(
          _form([
            _c(loteria: 'valle'),
            _c(loteria: 'cruz_roja'),
            _c(loteria: 'valle'),
          ]),
        );
        expect(r.comprobantes.map((c) => c.loteria), [
          'valle',
          'cruz_roja',
          'valle',
        ]);
      });

      test('los dos roles la exigen', () {
        for (final rol in ReviewRole.values) {
          final numeros = rol == ReviewRole.revisor
              ? const ['1']
              : const <String>[];
          expect(
            _failure(_form([_c(numeros: numeros, loteria: null)]), rol),
            const ImageReviewFailure.loteriaInvalida(1),
            reason: rol.name,
          );
          expect(
            validateImageReviewForm(
              _form([_c(numeros: numeros, loteria: 'meta')]),
              rol,
            ).isRight(),
            isTrue,
            reason: rol.name,
          );
        }
      });
    });

    group('números', () {
      test('lista vacía -> comprobanteSinNumeros', () {
        expect(
          _failure(_form([_c(numeros: const [])])),
          const ImageReviewFailure.comprobanteSinNumeros(1),
        );
      });

      test('solo vacíos/espacios -> comprobanteSinNumeros', () {
        expect(
          _failure(
            _form([
              _c(numeros: ['', '  ']),
            ]),
          ),
          const ImageReviewFailure.comprobanteSinNumeros(1),
        );
      });

      test('trim y descarte de vacíos', () {
        final r = _ok(
          _form([
            _c(numeros: [' 5311 ', '', '  ', '1111']),
          ]),
        );
        expect(r.comprobantes.single.numeros, ['5311', '1111']);
      });

      test('conserva ceros a la izquierda', () {
        final r = _ok(
          _form([
            _c(numeros: ['0123', '123']),
          ]),
        );
        expect(r.comprobantes.single.numeros, ['0123', '123']);
      });
    });

    group('total', () {
      test('0 -> totalInvalido', () {
        expect(
          _failure(_form([_c(total: 0)])),
          const ImageReviewFailure.totalInvalido(1),
        );
      });

      test('negativo -> totalInvalido', () {
        expect(
          _failure(_form([_c(total: -500)])),
          const ImageReviewFailure.totalInvalido(1),
        );
      });

      test('1 es válido', () {
        _ok(_form([_c(total: 1)]));
      });
    });

    group('orden e índice', () {
      test('reporta el índice (1-based) del comprobante con error', () {
        expect(
          _failure(_form([_c(), _c(total: 0)])),
          const ImageReviewFailure.totalInvalido(2),
        );
      });

      test('el código de la imagen va primero (antes que comprobantes, '
          'números y total)', () {
        expect(
          _failure(_form(const [], codigo: '')),
          const ImageReviewFailure.codigoVacio(),
        );
        expect(
          _failure(_form([_c(numeros: const [], total: 0)], codigo: '')),
          const ImageReviewFailure.codigoVacio(),
        );
      });

      test('por comprobante: números, luego total, luego lotería', () {
        expect(
          _failure(_form([_c(numeros: const [], total: 0, loteria: null)])),
          const ImageReviewFailure.comprobanteSinNumeros(1),
        );
        expect(
          _failure(_form([_c(total: 0, loteria: null)])),
          const ImageReviewFailure.totalInvalido(1),
        );
        expect(
          _failure(_form([_c(loteria: null)])),
          const ImageReviewFailure.loteriaInvalida(1),
        );
      });

      test('fail-fast: la lotería de un comprobante anterior gana al total '
          'del siguiente', () {
        expect(
          _failure(_form([_c(loteria: null), _c(total: 0)])),
          const ImageReviewFailure.loteriaInvalida(1),
        );
      });

      test('fail-fast: un comprobante anterior con error gana', () {
        expect(
          _failure(_form([_c(numeros: const []), _c(total: 0)])),
          const ImageReviewFailure.comprobanteSinNumeros(1),
        );
      });
    });

    group('anotaciones', () {
      test('null se mantiene null', () {
        expect(_ok(_form([_c()])).anotaciones, isNull);
      });

      test('vacías -> null', () {
        final r = _ok(_form([_c()], anotaciones: ''));
        expect(r.anotaciones, isNull);
      });

      test('solo espacios -> null', () {
        final r = _ok(_form([_c()], anotaciones: ' \n  '));
        expect(r.anotaciones, isNull);
      });

      test('con texto se guardan con trim', () {
        final r = _ok(_form([_c()], anotaciones: '  ilegible '));
        expect(r.anotaciones, 'ilegible');
      });

      test('no afectan la validación', () {
        expect(
          validateImageReviewForm(
            _form(const [], anotaciones: 'nota'),
            ReviewRole.revisor,
          ).isLeft(),
          isTrue,
        );
      });
    });
  });

  group('validateImageReviewForm como Sumador', () {
    const sumador = ReviewRole.sumador;

    Comprobante c({
      List<String> numeros = const [],
      int total = 9000,
      String? loteria = _loteria,
    }) => _c(numeros: numeros, total: total, loteria: loteria);

    test('código de la imagen y total, sin números: es válido', () {
      final form = _form([c()]);
      expect(_ok(form, sumador), form);
    });

    test('sin comprobantes -> sinComprobantes', () {
      expect(
        _failure(_form(const []), sumador),
        const ImageReviewFailure.sinComprobantes(),
      );
    });

    test('código ausente, vacío o solo espacios -> codigoVacio', () {
      for (final codigo in [null, '', '   ']) {
        expect(
          _failure(_form([c()], codigo: codigo), sumador),
          const ImageReviewFailure.codigoVacio(),
          reason: '"$codigo"',
        );
      }
    });

    test('al código se le aplica trim', () {
      final r = _ok(_form([c()], codigo: '  A1 '), sumador);
      expect(r.codigo, 'A1');
    });

    test('también exige la lotería de cada comprobante, de la lista', () {
      expect(
        _failure(_form([c(loteria: null)]), sumador),
        const ImageReviewFailure.loteriaInvalida(1),
      );
      expect(
        _failure(_form([c(), c(loteria: 'baloto')]), sumador),
        const ImageReviewFailure.loteriaInvalida(2),
      );
      final r = _ok(_form([c(loteria: 'valle'), c(loteria: 'meta')]), sumador);
      expect(r.comprobantes.map((x) => x.loteria), ['valle', 'meta']);
    });

    test('total 0 o negativo -> totalInvalido; 1 es válido', () {
      expect(
        _failure(_form([c(total: 0)]), sumador),
        const ImageReviewFailure.totalInvalido(1),
      );
      expect(
        _failure(_form([c(total: -1)]), sumador),
        const ImageReviewFailure.totalInvalido(1),
      );
      _ok(_form([c(total: 1)]), sumador);
    });

    test('NO exige números: la lista vacía no es error', () {
      final r = _ok(_form([c(numeros: const [])]), sumador);
      expect(r.comprobantes.single.numeros, isEmpty);
    });

    test('los números que lleguen se descartan (lista vacía)', () {
      final r = _ok(
        _form([
          c(numeros: ['5311', ' 1111 ', '']),
        ]),
        sumador,
      );
      expect(r.comprobantes.single.numeros, isEmpty);
    });

    test('orden: código, comprobantes y total; índice 1-based', () {
      expect(
        _failure(_form([c(total: 0)], codigo: ''), sumador),
        const ImageReviewFailure.codigoVacio(),
      );
      expect(
        _failure(_form([c(), c(total: 0)]), sumador),
        const ImageReviewFailure.totalInvalido(2),
      );
    });

    test('anotaciones opcionales: vacías -> null, con texto con trim', () {
      expect(_ok(_form([c()], anotaciones: '  '), sumador).anotaciones, isNull);
      expect(
        _ok(_form([c()], anotaciones: ' nota '), sumador).anotaciones,
        'nota',
      );
    });

    test('el Revisor con esos mismos datos (sin números) sigue fallando', () {
      expect(
        _failure(_form([c(numeros: const [])])),
        const ImageReviewFailure.comprobanteSinNumeros(1),
      );
    });
  });

  group('mapFailureToMessage con ImageReviewFailure', () {
    test('mensajes en español', () {
      expect(
        mapFailureToMessage(const ImageReviewFailure.sinComprobantes()),
        'Agrega al menos un comprobante',
      );
      expect(
        mapFailureToMessage(const ImageReviewFailure.codigoVacio()),
        'Ingresa el código de la imagen',
      );
      expect(
        mapFailureToMessage(const ImageReviewFailure.comprobanteSinNumeros(3)),
        'Comprobante 3: agrega al menos un número',
      );
      expect(
        mapFailureToMessage(const ImageReviewFailure.totalInvalido(1)),
        'Comprobante 1: el total debe ser mayor que 0',
      );
      expect(
        mapFailureToMessage(const ImageReviewFailure.loteriaInvalida(2)),
        'Comprobante 2: elige la lotería',
      );
    });
  });
}
