import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/image_review_failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';

const _target = ImageReviewTarget(
  messageId: 'm1',
  chatJid: 'chat@g.us',
  shift: 'Jornada Mañana',
);

({String messageId, ReviewRole rol}) _key(ReviewRole rol, [String id = 'm1']) =>
    (messageId: id, rol: rol);

void main() {
  group('parseReviewRole / currentReviewRoleProvider', () {
    late List<String> logs;

    setUp(() {
      logs = [];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => logs.add(message ?? '');
      addTearDown(() => debugPrint = original);
    });

    test('"revisor" y "sumador" se respetan, sin avisos', () {
      expect(parseReviewRole('revisor'), ReviewRole.revisor);
      expect(parseReviewRole('sumador'), ReviewRole.sumador);
      expect(logs, isEmpty);
    });

    test('un valor inválido cae en revisor y lo avisa con debugPrint', () {
      for (final value in ['admin', '', 'SUMADOR', ' sumador']) {
        logs.clear();
        expect(parseReviewRole(value), ReviewRole.revisor, reason: '"$value"');
        expect(logs, hasLength(1), reason: '"$value"');
        expect(logs.single, contains('REVIEW_ROLE'));
      }
    });

    test('sin --dart-define el rol activo por defecto es revisor', () {
      // Válido cuando los tests corren sin --dart-define=REVIEW_ROLE=...
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(currentReviewRoleProvider), ReviewRole.revisor);
      expect(logs, isEmpty);
    });

    test('en los tests el rol se elige con un override', () {
      final container = ProviderContainer(
        overrides: [
          currentReviewRoleProvider.overrideWithValue(ReviewRole.sumador),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentReviewRoleProvider), ReviewRole.sumador);
    });
  });

  group('cada rol ve solo lo suyo', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [reviewerEmailProvider.overrideWithValue('a@x.com')],
      );
      addTearDown(container.dispose);
    });

    /// Diligencia y guarda el formulario de [rol] para [id] (sin tocar el otro).
    Future<void> saveAs(
      ReviewRole rol, {
      String id = 'm1',
      String codigo = 'A1',
      String total = '9000',
      bool withNumbers = true,
    }) async {
      final draft = container.read(reviewDraftProvider(_key(rol, id)).notifier);
      draft.setCodigo(0, codigo);
      if (rol == ReviewRole.revisor && withNumbers) {
        draft.setNumeroPendiente(0, '0123');
      }
      draft.setTotal(0, total);
      await draft.save(_target);
    }

    test('lo guardado como Revisor no aparece como Sumador', () async {
      await saveAs(ReviewRole.revisor);

      expect(
        await container.read(
          savedRecordProvider(_key(ReviewRole.revisor)).future,
        ),
        isNotNull,
      );
      expect(
        await container.read(
          savedRecordProvider(_key(ReviewRole.sumador)).future,
        ),
        isNull,
      );
      expect(
        container.read(canAdvanceProvider(_key(ReviewRole.revisor))),
        isTrue,
      );
      expect(
        container.read(canAdvanceProvider(_key(ReviewRole.sumador))),
        isFalse,
      );
    });

    test('lo guardado como Sumador no aparece como Revisor', () async {
      await saveAs(ReviewRole.sumador);

      expect(
        await container.read(
          savedRecordProvider(_key(ReviewRole.sumador)).future,
        ),
        isNotNull,
      );
      expect(
        await container.read(
          savedRecordProvider(_key(ReviewRole.revisor)).future,
        ),
        isNull,
      );
      expect(
        container.read(canAdvanceProvider(_key(ReviewRole.sumador))),
        isTrue,
      );
      expect(
        container.read(canAdvanceProvider(_key(ReviewRole.revisor))),
        isFalse,
      );
    });

    test('los dos guardan la misma imagen sin pisarse', () async {
      await saveAs(ReviewRole.revisor, total: '9000');
      await saveAs(ReviewRole.sumador, total: '9500');

      final revisor = await container.read(
        savedRecordProvider(_key(ReviewRole.revisor)).future,
      );
      final sumador = await container.read(
        savedRecordProvider(_key(ReviewRole.sumador)).future,
      );

      expect(revisor!.rol, ReviewRole.revisor);
      expect(revisor.form.comprobantes.single.total, 9000);
      expect(revisor.form.comprobantes.single.numeros, ['0123']);
      expect(sumador!.rol, ReviewRole.sumador);
      expect(sumador.form.comprobantes.single.total, 9500);
      expect(sumador.form.comprobantes.single.numeros, isEmpty);
      expect(sumador.registradoPor, 'a@x.com');
    });

    test('editado es independiente por rol', () async {
      await saveAs(ReviewRole.revisor);
      await saveAs(ReviewRole.sumador);

      // Solo el Revisor re-guarda: solo su registro queda como editado.
      final draft = container.read(
        reviewDraftProvider(_key(ReviewRole.revisor)).notifier,
      );
      draft.startEditing(
        (await container.read(
          savedRecordProvider(_key(ReviewRole.revisor)).future,
        ))!,
      );
      draft.setTotal(0, '12000');
      await draft.save(_target);

      final revisor = await container.read(
        savedRecordProvider(_key(ReviewRole.revisor)).future,
      );
      final sumador = await container.read(
        savedRecordProvider(_key(ReviewRole.sumador)).future,
      );
      expect(revisor!.editado, isTrue);
      expect(sumador!.editado, isFalse);
      expect(sumador.form.comprobantes.single.total, 9000);
    });

    test('cada rol tiene su propio borrador de la misma imagen', () {
      container
          .read(reviewDraftProvider(_key(ReviewRole.revisor)).notifier)
          .setCodigo(0, 'REV');
      container
          .read(reviewDraftProvider(_key(ReviewRole.sumador)).notifier)
          .setTotal(0, '777');

      final revisor = container.read(
        reviewDraftProvider(_key(ReviewRole.revisor)),
      );
      final sumador = container.read(
        reviewDraftProvider(_key(ReviewRole.sumador)),
      );
      expect(revisor.comprobantes.single.codigo, 'REV');
      expect(revisor.comprobantes.single.total, isEmpty);
      expect(sumador.comprobantes.single.codigo, isEmpty);
      expect(sumador.comprobantes.single.total, '777');
    });

    test('el Sumador guarda sin números; el Revisor con lo mismo no', () async {
      await saveAs(ReviewRole.sumador, withNumbers: false);
      expect(
        container.read(reviewDraftProvider(_key(ReviewRole.sumador))).saveError,
        isNull,
      );

      await saveAs(ReviewRole.revisor, withNumbers: false);
      expect(
        container.read(reviewDraftProvider(_key(ReviewRole.revisor))).saveError,
        const ImageReviewFailure.comprobanteSinNumeros(1),
      );
    });

    test('un número tipeado como Sumador no se guarda', () async {
      final draft = container.read(
        reviewDraftProvider(_key(ReviewRole.sumador)).notifier,
      );
      draft.setCodigo(0, 'A1');
      draft.setNumeroPendiente(0, '5311'); // no debería pasar por la UI
      draft.setTotal(0, '500');
      await draft.save(_target);

      final record = await container.read(
        savedRecordProvider(_key(ReviewRole.sumador)).future,
      );
      expect(record!.form.comprobantes.single.numeros, isEmpty);
    });
  });
}
