import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_provider.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_providers.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_local_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';

const _target = ImageReviewTarget(
  messageId: 'm1',
  chatJid: 'chat@g.us',
  shift: 'Jornada Mañana',
  storagePath: 'img_m1.png',
  fechaJornada: '2026-01-15',
);

({String messageId, ReviewRole rol}) _key(
  String id, [
  ReviewRole rol = ReviewRole.revisor,
]) => (messageId: id, rol: rol);

AuthenticatedUser _user(String uid, String email) => AuthenticatedUser(
  id: uid,
  email: email,
  isAdmin: false,
  isSuperAdmin: false,
);

/// Sesión falsa: no toca Firebase ni los otros notifiers.
class _FakeAuth extends AuthSessionNotifier {
  @override
  AuthSessionState build() =>
      AuthSessionState.authenticated(_user('uid-a', 'a@x.com'));

  @override
  Future<void> logout() async =>
      state = const AuthSessionState.unauthenticated();

  @override
  void setAuthenticated(AuthenticatedUser user) =>
      state = AuthSessionState.authenticated(user);
}

void main() {
  late Directory dir;
  late ReviewLocalDatasource datasource;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('review_session_');
    datasource = (await ReviewLocalDatasource.open(
      path: dir.path,
    )).getOrElse(() => fail('no se pudo abrir el almacenamiento'));
    container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_FakeAuth.new),
        reviewLocalStorageProvider.overrideWithValue(Right(datasource)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await datasource.close();
      await dir.delete(recursive: true);
    });
  });

  Future<void> saveValidRecord({
    String id = 'm1',
    ReviewRole rol = ReviewRole.revisor,
  }) async {
    final draft = container.read(reviewDraftProvider(_key(id, rol)).notifier);
    draft.setCodigo(0, 'A1');
    if (rol == ReviewRole.revisor) draft.setNumeroPendiente(0, '0123');
    draft.setTotal(0, '9000');
    await draft.save(
      ImageReviewTarget(
        messageId: id,
        chatJid: 'chat@g.us',
        shift: 'Jornada Mañana',
        storagePath: 'img_$id.png',
        fechaJornada: '2026-01-15',
      ),
    );
  }

  Future<List<String>> pendingIds() async =>
      (await container
              .read(imageReviewRepositoryProvider)
              .getPending(
                chatJid: 'chat@g.us',
                fechaJornada: '2026-01-15',
                shift: 'Jornada Mañana',
                rol: ReviewRole.revisor,
              ))
          .getOrElse(() => fail('Left'))
          .map((r) => r.messageId)
          .toList();

  test('reviewerUidProvider sigue a la sesión (uid, no email)', () {
    expect(container.read(reviewerUidProvider), 'uid-a');
    expect(container.read(reviewerEmailProvider), 'a@x.com');
  });

  test('al cerrar sesión no se ven registros ni borradores, pero los '
      'registros siguen guardados', () async {
    await saveValidRecord();
    expect(container.read(reviewDraftProvider(_key('m1'))).saveError, isNull);
    expect(
      await container.read(savedRecordProvider(_key('m1')).future),
      isNotNull,
    );
    expect(container.read(canAdvanceProvider(_key('m1'))), isTrue);

    // Un borrador sin guardar de otra imagen se pierde (solo está en memoria).
    container.read(reviewDraftProvider(_key('m2')).notifier).setCodigo(0, 'X9');

    await container.read(authSessionProvider.notifier).logout();

    expect(container.read(reviewerUidProvider), isNull);
    expect(
      await container.read(savedRecordProvider(_key('m1')).future),
      isNull,
    );
    expect(container.read(canAdvanceProvider(_key('m1'))), isFalse);
    expect(
      container
          .read(reviewDraftProvider(_key('m2')))
          .comprobantes
          .single
          .codigo,
      isEmpty,
    );

    // Nada se borró del almacenamiento: al volver el mismo usuario, sigue ahí.
    container
        .read(authSessionProvider.notifier)
        .setAuthenticated(_user('uid-a', 'a@x.com'));
    final back = await container.read(savedRecordProvider(_key('m1')).future);
    expect(back, isNotNull);
    expect(back!.registradoPor, 'a@x.com');
    expect(back.form.comprobantes.single.numeros, ['0123']);
  });

  test('otro usuario del mismo navegador no ve lo del anterior, guarda solo '
      'lo suyo y el primero lo conserva', () async {
    await saveValidRecord();

    final auth = container.read(authSessionProvider.notifier);
    await auth.logout();
    auth.setAuthenticated(_user('uid-b', 'b@x.com'));

    expect(
      await container.read(savedRecordProvider(_key('m1')).future),
      isNull,
    );

    await saveValidRecord();
    final recordB = await container.read(
      savedRecordProvider(_key('m1')).future,
    );
    expect(recordB!.registradoPor, 'b@x.com');
    expect(recordB.editado, isFalse); // no existía para este usuario

    // Vuelve A: su registro intacto, no el de B.
    await auth.logout();
    auth.setAuthenticated(_user('uid-a', 'a@x.com'));
    final recordA = await container.read(
      savedRecordProvider(_key('m1')).future,
    );
    expect(recordA!.registradoPor, 'a@x.com');
    expect(recordA.editado, isFalse);
  });

  test('el uid, no el email, separa a los usuarios', () async {
    await saveValidRecord();

    // Mismo email, otro uid: es otro usuario.
    final auth = container.read(authSessionProvider.notifier);
    await auth.logout();
    auth.setAuthenticated(_user('uid-c', 'a@x.com'));

    expect(
      await container.read(savedRecordProvider(_key('m1')).future),
      isNull,
    );
  });

  test('sin sesión no se guarda y queda un error', () async {
    await container.read(authSessionProvider.notifier).logout();

    await saveValidRecord();

    expect(
      container.read(reviewDraftProvider(_key('m1'))).saveError,
      isNotNull,
    );
    expect(
      await container.read(savedRecordProvider(_key('m1')).future),
      isNull,
    );
  });

  test('guarda la referencia de imagen, la fecha de la jornada y queda '
      'pendiente', () async {
    await saveValidRecord();

    final record = await container.read(savedRecordProvider(_key('m1')).future);
    expect(record!.storagePath, 'img_m1.png');
    expect(record.fechaJornada, '2026-01-15');
    expect(record.estadoSync, EstadoSync.pendiente);
    expect(record.editado, isFalse);
    expect(await pendingIds(), ['m1']);
  });

  test('editar un registro sincronizado lo devuelve a pendiente con '
      'editado = true', () async {
    await saveValidRecord();
    final saved = (await container.read(
      savedRecordProvider(_key('m1')).future,
    ))!;

    // Simula lo que hará la subida (todavía no existe): lo marca sincronizado.
    await container
        .read(imageReviewRepositoryProvider)
        .save(saved.copyWith(estadoSync: EstadoSync.sincronizado));
    container.invalidate(savedRecordProvider(_key('m1')));
    final synced = (await container.read(
      savedRecordProvider(_key('m1')).future,
    ))!;
    expect(synced.estadoSync, EstadoSync.sincronizado);
    expect(await pendingIds(), isEmpty);

    // Editar y re-guardar.
    final draft = container.read(reviewDraftProvider(_key('m1')).notifier);
    draft.startEditing(synced);
    draft.setTotal(0, '12000');
    await draft.save(_target);

    final edited = (await container.read(
      savedRecordProvider(_key('m1')).future,
    ))!;
    expect(edited.editado, isTrue);
    expect(edited.estadoSync, EstadoSync.pendiente);
    expect(edited.form.comprobantes.single.total, 12000);
    expect(await pendingIds(), ['m1']);
  });

  test('si el almacenamiento no se pudo abrir, la lectura y el guardado '
      'fallan con el error, sin romper la app', () async {
    const failure = Failure.storage(
      message: 'No se pudo abrir el almacenamiento local de este dispositivo',
    );
    final broken = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_FakeAuth.new),
        reviewLocalStorageProvider.overrideWithValue(const Left(failure)),
      ],
    );
    addTearDown(broken.dispose);

    await expectLater(
      broken.read(savedRecordProvider(_key('m1')).future),
      throwsA(failure),
    );

    final draft = broken.read(reviewDraftProvider(_key('m1')).notifier);
    draft.setCodigo(0, 'A1');
    draft.setNumeroPendiente(0, '0123');
    draft.setTotal(0, '9000');
    await draft.save(_target);
    expect(broken.read(reviewDraftProvider(_key('m1'))).saveError, failure);
  });
}
