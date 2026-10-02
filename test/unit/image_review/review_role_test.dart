import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/image_review_failure.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_provider.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';

/// Sesión falsa que no toca Firebase: fija el estado que devuelve `build()`.
class _FakeAuth extends AuthSessionNotifier {
  final AuthSessionState _state;
  _FakeAuth(this._state);

  @override
  AuthSessionState build() => _state;
}

AuthenticatedUser _user({ReviewRole? reviewRole}) => AuthenticatedUser(
  id: 'uid-a',
  email: 'a@x.com',
  isAdmin: false,
  isSuperAdmin: false,
  reviewRole: reviewRole,
);

const _target = ImageReviewTarget(
  messageId: 'm1',
  chatJid: 'chat@g.us',
  shift: 'Jornada Mañana',
  storagePath: 'img_m1.png',
  fechaJornada: '2026-01-15',
  messageTimestamp: 1788489942000,
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

    test(
      'un valor inválido o vacío es "sin rol" y lo avisa con debugPrint',
      () {
        for (final value in ['admin', '', 'SUMADOR', ' sumador']) {
          logs.clear();
          expect(parseReviewRole(value), isNull, reason: '"$value"');
          expect(logs, hasLength(1), reason: '"$value"');
          expect(logs.single, contains('REVIEW_ROLE'));
          expect(logs.single, contains('sin rol activo'));
        }
      },
    );

    test('sin sesión autenticada real y sin --dart-define, el rol activo por '
        'defecto es null (sin rol)', () {
      // Sin override de authSessionProvider caería a Firebase real (no
      // inicializado en este test); una sesión "unauthenticated" simulada
      // basta para ejercer la rama del fallback sin tocarlo.
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuth(const AuthSessionState.unauthenticated()),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentReviewRoleProvider), isNull);
      expect(logs, hasLength(1));
      expect(logs.single, contains('sin rol activo'));
    });

    test('con sesión autenticada, el rol real es el `reviewRole` del claim '
        '(sin caer al --dart-define, aunque sea null)', () {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuth(
              AuthSessionState.authenticated(
                _user(reviewRole: ReviewRole.sumador),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentReviewRoleProvider), ReviewRole.sumador);
      // El claim manda: ni siquiera se evalúa el fallback, sin avisos.
      expect(logs, isEmpty);
    });

    test('con sesión autenticada pero sin reviewRole, el rol es null y NO cae '
        'al --dart-define', () {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(
            () => _FakeAuth(AuthSessionState.authenticated(_user())),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(currentReviewRoleProvider), isNull);
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

    test('un override a null explícito representa "sin rol"', () {
      final container = ProviderContainer(
        overrides: [currentReviewRoleProvider.overrideWithValue(null)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentReviewRoleProvider), isNull);
    });
  });

  group('cada rol ve solo lo suyo', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [
          reviewerEmailProvider.overrideWithValue('a@x.com'),
          reviewerUidProvider.overrideWithValue('uid-test'),
          imageReviewRepositoryProvider.overrideWithValue(
            InMemoryImageReviewRepository(),
          ),
        ],
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
      draft.setCodigo(codigo);
      if (rol == ReviewRole.revisor && withNumbers) {
        draft.setNumeroPendiente(0, '0123');
      }
      draft.setTotal(0, total);
      await draft.save(_target);
    }

    test('save() guarda el messageTimestamp del target sin transformarlo, en '
        'los dos roles', () async {
      await saveAs(ReviewRole.revisor);
      await saveAs(ReviewRole.sumador);

      for (final rol in ReviewRole.values) {
        final saved = await container.read(
          savedRecordProvider(_key(rol)).future,
        );
        expect(saved!.messageTimestamp, _target.messageTimestamp);
        expect(saved.messageTimestamp, 1788489942000);
      }
    });

    test(
      'save() guarda el código de la imagen (con trim) y la lotería de '
      'cada comprobante (con trim; vacía -> null), en los dos roles',
      () async {
        for (final rol in ReviewRole.values) {
          final draft = container.read(reviewDraftProvider(_key(rol)).notifier);
          draft.setCodigo('  0457 ');
          if (rol == ReviewRole.revisor) draft.setNumeroPendiente(0, '0123');
          draft.setTotal(0, '9000');
          draft.setLoteria(0, ' Lotería de Medellín ');
          draft.addComprobante();
          final second = container
              .read(reviewDraftProvider(_key(rol)))
              .comprobantes
              .last
              .id;
          // Al agregar un comprobante, su lotería arranca vacía.
          expect(
            container
                .read(reviewDraftProvider(_key(rol)))
                .comprobantes
                .last
                .loteria,
            isEmpty,
          );
          if (rol == ReviewRole.revisor) {
            draft.setNumeroPendiente(second, '5311');
          }
          draft.setTotal(second, '3000');
          draft.setLoteria(second, '   ');
          await draft.save(_target);

          final saved = await container.read(
            savedRecordProvider(_key(rol)).future,
          );
          expect(saved!.form.codigo, '0457', reason: rol.name);
          expect(saved.form.comprobantes.map((c) => c.loteria), [
            'Lotería de Medellín',
            null,
          ], reason: rol.name);
        }
      },
    );

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
          .setCodigo('REV');
      container
          .read(reviewDraftProvider(_key(ReviewRole.sumador)).notifier)
          .setTotal(0, '777');

      final revisor = container.read(
        reviewDraftProvider(_key(ReviewRole.revisor)),
      );
      final sumador = container.read(
        reviewDraftProvider(_key(ReviewRole.sumador)),
      );
      expect(revisor.codigo, 'REV');
      expect(revisor.comprobantes.single.total, isEmpty);
      expect(sumador.codigo, isEmpty);
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
      draft.setCodigo('A1');
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
