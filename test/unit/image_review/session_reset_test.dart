import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_provider.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';

const _target = ImageReviewTarget(
  messageId: 'm1',
  chatJid: 'chat@g.us',
  shift: 'Jornada Mañana',
);

AuthenticatedUser _user(String email) => AuthenticatedUser(
  id: email,
  email: email,
  isAdmin: false,
  isSuperAdmin: false,
);

/// Sesión falsa: no toca Firebase ni los otros notifiers.
class _FakeAuth extends AuthSessionNotifier {
  @override
  AuthSessionState build() => AuthSessionState.authenticated(_user('a@x.com'));

  @override
  Future<void> logout() async =>
      state = const AuthSessionState.unauthenticated();

  @override
  void setAuthenticated(AuthenticatedUser user) =>
      state = AuthSessionState.authenticated(user);
}

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [authSessionProvider.overrideWith(_FakeAuth.new)],
    );
    addTearDown(container.dispose);
  });

  Future<void> saveValidRecord() async {
    final draft = container.read(
      reviewDraftProvider((messageId: 'm1', rol: ReviewRole.revisor)).notifier,
    );
    draft.setCodigo(0, 'A1');
    draft.setNumeroPendiente(0, '0123');
    draft.setTotal(0, '9000');
    await draft.save(_target);
  }

  test('reviewerEmailProvider sigue a la sesión', () {
    expect(container.read(reviewerEmailProvider), 'a@x.com');
  });

  test('al cerrar sesión se descartan registros y borradores', () async {
    await saveValidRecord();
    expect(
      container
          .read(reviewDraftProvider((messageId: 'm1', rol: ReviewRole.revisor)))
          .saveError,
      isNull,
    );
    expect(
      await container.read(
        savedRecordProvider((messageId: 'm1', rol: ReviewRole.revisor)).future,
      ),
      isNotNull,
    );
    expect(
      container.read(
        canAdvanceProvider((messageId: 'm1', rol: ReviewRole.revisor)),
      ),
      isTrue,
    );

    // Un borrador sin guardar de otra imagen también debe desaparecer.
    container
        .read(
          reviewDraftProvider((
            messageId: 'm2',
            rol: ReviewRole.revisor,
          )).notifier,
        )
        .setCodigo(0, 'X9');

    await container.read(authSessionProvider.notifier).logout();

    expect(container.read(reviewerEmailProvider), isNull);
    expect(
      await container.read(
        savedRecordProvider((messageId: 'm1', rol: ReviewRole.revisor)).future,
      ),
      isNull,
    );
    expect(
      container.read(
        canAdvanceProvider((messageId: 'm1', rol: ReviewRole.revisor)),
      ),
      isFalse,
    );
    expect(
      container
          .read(reviewDraftProvider((messageId: 'm1', rol: ReviewRole.revisor)))
          .comprobantes
          .single
          .codigo,
      isEmpty,
    );
    expect(
      container
          .read(reviewDraftProvider((messageId: 'm2', rol: ReviewRole.revisor)))
          .comprobantes
          .single
          .codigo,
      isEmpty,
    );
  });

  test('otro usuario no ve lo del anterior y guarda con su correo', () async {
    await saveValidRecord();

    final auth = container.read(authSessionProvider.notifier);
    await auth.logout();
    auth.setAuthenticated(_user('b@x.com'));

    expect(
      await container.read(
        savedRecordProvider((messageId: 'm1', rol: ReviewRole.revisor)).future,
      ),
      isNull,
    );

    await saveValidRecord();
    final record = await container.read(
      savedRecordProvider((messageId: 'm1', rol: ReviewRole.revisor)).future,
    );
    expect(record!.registradoPor, 'b@x.com');
    expect(record.editado, isFalse); // no existía para este usuario
  });

  test('sin sesión no se guarda y queda un error', () async {
    await container.read(authSessionProvider.notifier).logout();

    await saveValidRecord();

    expect(
      container
          .read(reviewDraftProvider((messageId: 'm1', rol: ReviewRole.revisor)))
          .saveError,
      isNotNull,
    );
    expect(
      await container.read(
        savedRecordProvider((messageId: 'm1', rol: ReviewRole.revisor)).future,
      ),
      isNull,
    );
  });
}
