import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/app/auth_redirect.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/auth/domain/entities/authenticated_user.dart';
import 'package:whatsapp_monitor_viewer/features/auth/presentation/providers/auth_session_state.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_remote_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/pages/review_session_page.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/jornada_images_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_session_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/image_review_panel.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/messages_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/repositories/messages_repository.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_repository_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';

import '../test_asset_bundle.dart';

/// Lunes 28 de septiembre de 2026: un día pasado (sin escucha en vivo).
final _day = DateTime(2026, 9, 28);

Message _msg(String id, int hour, int minute, {DateTime? day}) {
  final d = day ?? _day;
  final at = DateTime(d.year, d.month, d.day, hour, minute);
  return Message(
    id: id,
    chatJid: 'chat@g.us',
    senderName: 'Remitente $id',
    hasMedia: true,
    storagePath: 'img/$id.jpg',
    messageTimestamp: at.millisecondsSinceEpoch,
    localTime: '',
    shift: shiftViewerLabel(at),
    messageDate: '',
  );
}

class _FakeRepo implements MessagesRepository {
  final List<Message> messages;
  final StreamController<Message> live = StreamController<Message>();
  Failure? failure;
  int calls = 0;

  /// Si no es null, la lectura espera a que se complete (estado "cargando").
  Completer<void>? gate;

  _FakeRepo(this.messages);

  @override
  Future<Either<Failure, MessagesPage>> fetchByDateRange({
    required String chatJid,
    required int fromTimestamp,
    required int toTimestamp,
    int limit = 50,
    Object? cursor,
  }) async {
    calls++;
    await gate?.future;
    final failure = this.failure;
    if (failure != null) return Left(failure);
    return Right(MessagesPage(items: messages, nextCursor: null));
  }

  @override
  Stream<Message> listenNewMessages({
    required String chatJid,
    required int afterTimestamp,
  }) => live.stream;

  @override
  Future<Either<Failure, MessagesPage>> fetchInitial({
    required String chatJid,
    int limit = 50,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, MessagesPage>> fetchNext({
    required String chatJid,
    required Object cursor,
    int limit = 50,
  }) => throw UnimplementedError();
}

/// Registro guardado del Revisor para una imagen de la jornada de la sesión.
ImageReviewRecord _record(String id, {String fecha = '2026-09-28'}) =>
    ImageReviewRecord(
      messageId: id,
      chatJid: 'chat@g.us',
      shift: shiftNames[Shift.morning]!,
      rol: ReviewRole.revisor,
      storagePath: 'img/$id.jpg',
      fechaJornada: fecha,
      messageTimestamp: 1,
      form: const ImageReviewForm(
        codigo: 'A1',
        comprobantes: [
          Comprobante(numeros: ['0123'], total: 1000),
        ],
      ),
      registradoEn: DateTime(2026, 9, 28, 8),
      registradoPor: 'r@test.com',
    );

/// Uploader que solo anota lo que sube.
class _RecordingUploader implements ReviewUploader {
  final List<String> uploaded = [];

  /// Si no es null, cada subida espera a que se complete (subida "en curso").
  Completer<void>? gate;

  /// Si no es null, cada subida falla con este error (sin conexión, tiempo
  /// agotado).
  Failure? failWith;

  @override
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record) async {
    await gate?.future;
    final failure = failWith;
    if (failure != null) return Left(failure);
    uploaded.add(record.messageId);
    return const Right(unit);
  }
}

/// Lectura falsa de lo subido. Si [gate] no es null, espera a que se
/// complete (estado "cargando").
class _FakeRemote implements ReviewRemoteRecordsDatasource {
  Either<Failure, List<ImageReviewRecordModel>> result = const Right([]);
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<Either<Failure, List<ImageReviewRecordModel>>> fetchJornada({
    required String chatJid,
    required String fechaJornada,
    required Shift shift,
    required ReviewRole rol,
  }) async {
    calls++;
    await gate?.future;
    return result;
  }
}

/// El chat activo es el de la sesión (la sesión se abre desde ese chat).
class _SessionChat extends ActiveChatProvider {
  @override
  Chat? build() => Chat(
    chatJid: 'chat@g.us',
    groupName: 'Grupo Norte',
    lastMessageAt: 0,
    totalImages: 0,
  );
}

final ReviewSession _session = (
  jornada: (chatJid: 'chat@g.us', date: _day, shift: Shift.morning),
  groupName: 'Grupo Norte',
);

/// La pantalla de inicio de la prueba: un botón que empieza la sesión.
class _Home extends ConsumerWidget {
  const _Home();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: TextButton(
      onPressed: () => ref.read(reviewSessionProvider.notifier).start(_session),
      child: const Text('empezar'),
    ),
  );
}

/// Mismo cableado que `router.dart` (que no se puede importar en un test de
/// VM): el guard usa `computeAuthRedirect` y se reevalúa al cambiar la sesión.
GoRouter _router(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(path: '/home', builder: (_, _) => const _Home()),
      GoRoute(path: '/summary', builder: (_, _) => const Text('resumen')),
      GoRoute(path: '/review', builder: (_, _) => const ReviewSessionPage()),
    ],
    redirect: (_, state) => computeAuthRedirect(
      authState: AuthSessionState.authenticated(
        AuthenticatedUser(
          id: 'uid-test',
          email: 'r@test.com',
          isAdmin: true,
          isSuperAdmin: false,
          reviewRole: ReviewRole.revisor,
        ),
      ),
      location: state.matchedLocation,
      reviewSessionActive: container.read(reviewSessionProvider) != null,
    ),
  );
  container.listen(reviewSessionProvider, (_, _) => router.refresh());
  return router;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

typedef _App = ({
  ProviderContainer container,
  GoRouter router,
  InMemoryImageReviewRepository reviews,
  _RecordingUploader uploader,
  _FakeRemote remote,
});

Future<_App> _pump(
  WidgetTester tester, {
  required _FakeRepo repo,
  double width = 1280,
  List<ImageReviewRecord> records = const [],
  _FakeRemote? remote,
}) async {
  final fakeRemote = remote ?? _FakeRemote();
  final reviews = InMemoryImageReviewRepository();
  for (final record in records) {
    await reviews.save(record);
  }
  final uploader = _RecordingUploader();

  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      messagesRepositoryProvider.overrideWithValue(repo),
      imageUrlProvider.overrideWith((ref, path) => 'http://localhost/$path'),
      reviewerUidProvider.overrideWithValue('uid-test'),
      reviewerEmailProvider.overrideWithValue('r@test.com'),
      currentReviewRoleProvider.overrideWithValue(ReviewRole.revisor),
      reviewShiftsProvider.overrideWith(
        (ref) async => const [
          ReviewShift(chatJid: 'chat@g.us', shift: Shift.morning),
        ],
      ),
      imageReviewRepositoryProvider.overrideWithValue(reviews),
      reviewUploaderProvider.overrideWithValue(uploader),
      reviewRemoteRecordsDatasourceProvider.overrideWithValue(fakeRemote),
      activeChatProvider.overrideWith(_SessionChat.new),
    ],
  );
  addTearDown(container.dispose);
  final router = _router(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await _settle(tester);
  return (
    container: container,
    router: router,
    reviews: reviews,
    uploader: uploader,
    remote: fakeRemote,
  );
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.text('empezar'));
  await _settle(tester);
}

String? _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  setUpAll(setUpMockAssets);

  _main3b();

  tearDown(() {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('empezar la sesión lleva a /review con las imágenes de la '
      'jornada, desde la primera, y su formulario', (tester) async {
    final app = await _pump(
      tester,
      repo: _FakeRepo([
        _msg('segunda', 9, 0),
        _msg('tarde', 12, 0),
        _msg('primera', 6, 0),
      ]),
    );
    await _start(tester);

    expect(_location(app.router), '/review');
    expect(find.byType(ReviewSessionPage), findsOneWidget);
    expect(
      find.text('Grupo Norte · Mañana · 28 de septiembre de 2026'),
      findsOneWidget,
    );
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Remitente primera'), findsOneWidget);
    // Mismo panel del formulario que el visor del chat.
    expect(find.byType(ImageReviewPanel), findsOneWidget);
    // Sin botón de cerrar.
    expect(find.byTooltip('Cerrar'), findsNothing);
  });

  testWidgets('con sesión no se sale: ir a otra ruta (el "atrás" del '
      'navegador) vuelve a /review', (tester) async {
    final app = await _pump(tester, repo: _FakeRepo([_msg('a', 6, 0)]));
    await _start(tester);

    app.router.go('/home');
    await _settle(tester);
    expect(_location(app.router), '/review');

    app.router.go('/summary');
    await _settle(tester);
    expect(_location(app.router), '/review');
    expect(find.byType(ReviewSessionPage), findsOneWidget);
  });

  testWidgets('el gesto/botón "atrás" del sistema no saca de /review', (
    tester,
  ) async {
    final app = await _pump(tester, repo: _FakeRepo([_msg('a', 6, 0)]));
    await _start(tester);

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(_location(app.router), '/review');
    expect(find.byType(ReviewSessionPage), findsOneWidget);
  });

  testWidgets('sin sesión (recargar), /review lleva a /home', (tester) async {
    final app = await _pump(tester, repo: _FakeRepo([_msg('a', 6, 0)]));
    await _start(tester);

    app.container.read(reviewSessionProvider.notifier).end();
    await _settle(tester);

    expect(_location(app.router), '/home');
    expect(find.text('empezar'), findsOneWidget);
  });

  testWidgets('jornada sin imágenes: mensaje', (tester) async {
    await _pump(tester, repo: _FakeRepo([_msg('tarde', 12, 0)]));
    await _start(tester);

    expect(
      find.text('Todavía no hay imágenes de esta jornada'),
      findsOneWidget,
    );
    expect(find.byType(ImageDetailPage), findsNothing);
  });

  testWidgets('error al leer: mensaje y "Reintentar" vuelve a leer', (
    tester,
  ) async {
    final repo = _FakeRepo([_msg('a', 6, 0)])
      ..failure = const Failure.firestore(message: 'sin red');
    await _pump(tester, repo: repo);
    await _start(tester);

    expect(find.text('sin red'), findsOneWidget);

    repo.failure = null;
    await tester.tap(find.text('Reintentar'));
    await _settle(tester);

    expect(repo.calls, 2);
    expect(find.text('Remitente a'), findsOneWidget);
  });

  group('lo ya subido (al entrar)', () {
    final images = [_msg('a', 6, 0), _msg('b', 7, 0), _msg('c', 8, 0)];

    testWidgets('mientras se trae, cargando y sin formulario; al terminar, '
        'el visor', (tester) async {
      final remote = _FakeRemote()..gate = Completer<void>();
      await _pump(tester, repo: _FakeRepo(images), remote: remote);
      await _start(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ImageDetailPage), findsNothing);
      expect(find.byType(ImageReviewPanel), findsNothing);
      // La mezcla no terminó: "Cerrar" se ve (en la cabecera), deshabilitado.
      expect(_cerrar, findsOneWidget);
      expect(_cerrarHabilitado(tester), isFalse);

      remote.gate!.complete();
      await _settle(tester);

      expect(find.byType(ImageDetailPage), findsOneWidget);
      expect(find.byType(ImageReviewPanel), findsOneWidget);
      expect(_cerrarHabilitado(tester), isTrue);
      expect(remote.calls, 1);
    });

    testWidgets('error: mensaje, sin formulario, y "Reintentar" vuelve a '
        'traer', (tester) async {
      final remote = _FakeRemote()
        ..result = const Left(
          Failure.firestore(message: 'Servicio no disponible'),
        );
      await _pump(tester, repo: _FakeRepo(images), remote: remote);
      await _start(tester);

      expect(
        find.text(
          'No se pudieron traer los formularios ya subidos de esta jornada: '
          'Servicio no disponible',
        ),
        findsOneWidget,
      );
      expect(find.byType(ImageDetailPage), findsNothing);

      remote.result = const Right([]);
      await tester.tap(find.text('Reintentar'));
      await _settle(tester);

      expect(remote.calls, 2);
      expect(find.byType(ImageReviewPanel), findsOneWidget);
    });

    testWidgets('no autorizado: lo dice claro, sin formulario', (tester) async {
      final remote = _FakeRemote()..result = const Left(Failure.unauthorized());
      await _pump(tester, repo: _FakeRepo(images), remote: remote);
      await _start(tester);

      expect(
        find.textContaining('No tienes asignada esta jornada'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Recarga la página para salir'),
        findsOneWidget,
      );
      expect(find.text('No autorizado'), findsNothing);
      expect(find.byType(ImageDetailPage), findsNothing);
    });

    testWidgets('abre en la primera imagen sin formulario, contando lo traído '
        'de Firebase', (tester) async {
      final remote = _FakeRemote()
        ..result = Right([
          ImageReviewRecordModel(
            _record('b').copyWith(estadoSync: EstadoSync.sincronizado),
          ),
        ]);
      await _pump(
        tester,
        repo: _FakeRepo(images),
        records: [_record('a')],
        remote: remote,
      );
      await _start(tester);

      // a: pendiente local; b: subido (traído); c: sin formulario.
      expect(find.text('3 de 3'), findsOneWidget);
      expect(find.text('Remitente c'), findsOneWidget);
    });

    testWidgets('con todas llenas abre en la primera', (tester) async {
      final remote = _FakeRemote()
        ..result = Right([
          for (final id in ['b', 'c'])
            ImageReviewRecordModel(
              _record(id).copyWith(estadoSync: EstadoSync.sincronizado),
            ),
        ]);
      await _pump(
        tester,
        repo: _FakeRepo(images),
        records: [_record('a')],
        remote: remote,
      );
      await _start(tester);

      expect(find.text('1 de 3'), findsOneWidget);
      expect(find.text('Remitente a'), findsOneWidget);
      expect(_cerrar, findsOneWidget);
    });
  });

  test('la sesión se vacía si cambia el usuario', () {
    final container = ProviderContainer(
      overrides: [
        reviewerUidProvider.overrideWith((ref) => ref.watch(_uidProvider)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(reviewSessionProvider, (_, _) {});

    container.read(reviewSessionProvider.notifier).start(_session);
    expect(container.read(reviewSessionProvider), isNotNull);

    container.read(_uidProvider.notifier).set('uid-2');
    expect(container.read(reviewSessionProvider), isNull);
  });

  test('cerrar sesión (uid null) vacía la sesión y la misma persona, al '
      'volver a entrar, no recupera la vieja', () {
    final container = ProviderContainer(
      overrides: [
        reviewerUidProvider.overrideWith((ref) => ref.watch(_uidProvider)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(reviewSessionProvider, (_, _) {});

    container.read(reviewSessionProvider.notifier).start(_session);
    container.read(_uidProvider.notifier).set(null);
    expect(container.read(reviewSessionProvider), isNull);

    container.read(_uidProvider.notifier).set('uid-1');
    expect(container.read(reviewSessionProvider), isNull);
    // Y el guard la manda a /home, no a /review.
    expect(
      computeAuthRedirect(
        authState: AuthSessionState.authenticated(
          AuthenticatedUser(
            id: 'uid-1',
            email: 'r@test.com',
            isAdmin: false,
            isSuperAdmin: false,
            reviewRole: ReviewRole.revisor,
          ),
        ),
        location: '/login',
        reviewSessionActive: container.read(reviewSessionProvider) != null,
      ),
      '/home',
    );
  });
}

/// uid de prueba que se puede cambiar (simula logout/login con otra cuenta).
class _Uid extends Notifier<String?> {
  @override
  String? build() => 'uid-1';

  void set(String? uid) => state = uid;
}

final _uidProvider = NotifierProvider<_Uid, String?>(_Uid.new);

/// Botón "Cerrar" (en la barra del visor o en la cabecera).
final _cerrar = find.widgetWithText(ElevatedButton, 'Cerrar');

/// El botón "Cerrar" está habilitado (se ve siempre; se deshabilita mientras
/// se sube la jornada o la mezcla de lo ya subido no termina).
bool _cerrarHabilitado(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_cerrar).onPressed != null;

void _main3b() {
  group('Cerrar', () {
    testWidgets('el botón se ve con formularios sin terminar y con todos '
        'terminados, en el lugar del botón de cerrar de la imagen', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0), _msg('segunda', 9, 0)]),
        records: [_record('primera')],
      );
      await _start(tester);

      // Ajuste: antes no aparecía hasta que TODAS tenían formulario.
      expect(_cerrar, findsOneWidget);
      expect(_cerrarHabilitado(tester), isTrue);
      // Sin el icono de cerrar del visor del chat.
      expect(find.byTooltip('Cerrar'), findsNothing);

      // Se guarda la última (como lo haría el panel: guardar invalida el
      // registro guardado).
      await app.reviews.save(_record('segunda'));
      app.container.invalidate(savedRecordProvider);
      await _settle(tester);
      expect(_cerrar, findsOneWidget);
      expect(_cerrarHabilitado(tester), isTrue);
    });

    testWidgets('con registros sin subir, tocarlo abre el diálogo con su '
        'título, su texto y solo dos botones', (tester) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      await _start(tester);

      await tester.tap(_cerrar);
      await _settle(tester);

      expect(find.text('¿Salir de la revisión?'), findsOneWidget);
      expect(
        find.text('Lo que no se haya subido a la nube se puede perder.'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(
            ElevatedButton,
            'Subir a Firebase y salir',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(TextButton, 'Salir sin subir'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNWidgets(2),
      );
      // Todavía en la pantalla.
      expect(_location(app.router), '/review');
    });

    testWidgets('"Subir a Firebase y salir" sube (sin el diálogo "Subir '
        'registros") y después sale', (tester) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      await _start(tester);

      await tester.tap(_cerrar);
      await _settle(tester);
      await tester.tap(find.text('Subir a Firebase y salir'));
      await _settle(tester);

      expect(app.uploader.uploaded, ['primera']);
      expect(find.text('Subir registros'), findsNothing);
      expect(_location(app.router), '/home');
      expect(app.container.read(reviewSessionProvider), isNull);
    });

    testWidgets('si algún registro falla al subir, no sale: avisa con el '
        'mismo SnackBar y el registro sigue pendiente', (tester) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      app.uploader.failWith = const Failure.unknown(
        message: 'El registro no se pudo subir a tiempo.',
      );
      await _start(tester);

      await tester.tap(_cerrar);
      await _settle(tester);
      await tester.tap(find.text('Subir a Firebase y salir'));
      await _settle(tester);

      expect(_location(app.router), '/review');
      expect(app.container.read(reviewSessionProvider), isNotNull);
      expect(
        find.text('0 subidos, 1 no se pudieron subir; siguen pendientes'),
        findsOneWidget,
      );
      final saved = await app.reviews.getByMessageId(
        'primera',
        ReviewRole.revisor,
      );
      expect(
        saved.fold((_) => null, (r) => r)?.estadoSync,
        EstadoSync.pendiente,
      );
    });

    testWidgets('"Salir sin subir" sale sin llamar a la subida y sin tocar '
        'el registro del dispositivo', (tester) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      await _start(tester);

      await tester.tap(_cerrar);
      await _settle(tester);
      await tester.tap(find.text('Salir sin subir'));
      await _settle(tester);

      expect(app.uploader.uploaded, isEmpty);
      expect(_location(app.router), '/home');
      expect(app.container.read(reviewSessionProvider), isNull);
      final saved = await app.reviews.getByMessageId(
        'primera',
        ReviewRole.revisor,
      );
      expect(
        saved.fold((_) => null, (r) => r)?.estadoSync,
        EstadoSync.pendiente,
      );
    });

    testWidgets('tocar fuera del diálogo, o el "atrás" del sistema con el '
        'diálogo abierto, lo cierra: sigue en la pantalla sin subir', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      await _start(tester);

      // Fuera del diálogo.
      await tester.tap(_cerrar);
      await _settle(tester);
      expect(find.text('¿Salir de la revisión?'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await _settle(tester);
      expect(find.text('¿Salir de la revisión?'), findsNothing);
      expect(_location(app.router), '/review');
      expect(app.container.read(reviewSessionProvider), isNotNull);
      expect(app.uploader.uploaded, isEmpty);

      // El "atrás" del sistema con el diálogo abierto.
      await tester.tap(_cerrar);
      await _settle(tester);
      expect(find.text('¿Salir de la revisión?'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await _settle(tester);
      expect(find.text('¿Salir de la revisión?'), findsNothing);
      expect(_location(app.router), '/review');
      expect(app.container.read(reviewSessionProvider), isNotNull);
      expect(app.uploader.uploaded, isEmpty);
    });

    testWidgets('sin registros sin subir sale directo, sin diálogo', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [
          _record('primera').copyWith(estadoSync: EstadoSync.sincronizado),
        ],
      );
      await _start(tester);

      await tester.tap(_cerrar);
      await _settle(tester);

      expect(find.text('¿Salir de la revisión?'), findsNothing);
      expect(app.uploader.uploaded, isEmpty);
      expect(_location(app.router), '/home');
      expect(app.container.read(reviewSessionProvider), isNull);
    });

    testWidgets('con la lista vacía aparece (en la cabecera) y cierra directo '
        '(no hay registros sin subir)', (tester) async {
      final app = await _pump(tester, repo: _FakeRepo([_msg('tarde', 12, 0)]));
      await _start(tester);

      expect(
        find.text('Todavía no hay imágenes de esta jornada'),
        findsOneWidget,
      );
      await tester.tap(_cerrar);
      await _settle(tester);
      expect(_location(app.router), '/home');
    });

    // Ajuste: antes el botón no aparecía mientras cargaba; ahora se ve
    // deshabilitado (la protección es la misma).
    testWidgets('mientras carga la lectura inicial se ve deshabilitado (ni '
        'con la lista que resultará vacía)', (tester) async {
      final repo = _FakeRepo([_msg('tarde', 12, 0)])..gate = Completer<void>();
      final app = await _pump(tester, repo: repo);
      await _start(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(_cerrar, findsOneWidget);
      expect(_cerrarHabilitado(tester), isFalse);
      expect(
        app.container.read(reviewSessionCompleteProvider(_session.jornada)),
        isFalse,
      );

      repo.gate!.complete();
      await _settle(tester);
      // Ya leída (vacía): ahora se habilita.
      expect(_cerrarHabilitado(tester), isTrue);
    });

    testWidgets('con error de lectura se ve deshabilitado', (tester) async {
      await _pump(
        tester,
        repo: _FakeRepo([_msg('a', 6, 0)])
          ..failure = const Failure.firestore(message: 'sin red'),
      );
      await _start(tester);

      expect(find.text('sin red'), findsOneWidget);
      expect(_cerrar, findsOneWidget);
      expect(_cerrarHabilitado(tester), isFalse);
    });

    test(
      'una imagen nueva sin formulario lo oculta hasta que se guarde',
      () async {
        final today = DateUtils.dateOnly(DateTime.now());
        final noon = DateTime(today.year, today.month, today.day, 12);
        final shift = shiftFromLabel(shiftViewerLabel(noon))!;
        final key = (chatJid: 'chat@g.us', date: today, shift: shift);
        final fecha = fechaJornadaOf(key);
        final repo = _FakeRepo([_msg('a', 12, 0, day: today)]);
        final reviews = InMemoryImageReviewRepository();
        await reviews.save(
          _record('a', fecha: fecha).copyWith(shift: shiftNames[shift]!),
        );
        final container = ProviderContainer(
          overrides: [
            messagesRepositoryProvider.overrideWithValue(repo),
            reviewerUidProvider.overrideWithValue('uid-test'),
            currentReviewRoleProvider.overrideWithValue(ReviewRole.revisor),
            imageReviewRepositoryProvider.overrideWithValue(reviews),
          ],
        );
        addTearDown(container.dispose);
        final values = <bool>[];
        container.listen(
          reviewSessionCompleteProvider(key),
          (_, next) => values.add(next),
          fireImmediately: true,
        );
        await pumpEventQueue();
        expect(values.last, isTrue);

        repo.live.add(_msg('b', 12, 30, day: today));
        await pumpEventQueue();
        expect(values.last, isFalse);

        await reviews.save(
          _record('b', fecha: fecha).copyWith(shift: shiftNames[shift]!),
        );
        container.invalidate(savedRecordProvider);
        await pumpEventQueue();
        expect(values.last, isTrue);
      },
    );
  });

  group('Subir', () {
    testWidgets('aparece con el primer pendiente de la jornada y sube desde '
        '/review con ReviewUploadNotifier, sin cortarse', (tester) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0), _msg('segunda', 9, 0)]),
        records: [_record('primera')],
      );
      await _start(tester);
      expect(_location(app.router), '/review');

      expect(find.text('Subir · 1 pendiente'), findsOneWidget);
      await tester.tap(find.text('Subir · 1 pendiente'));
      await _settle(tester);
      expect(
        find.text('Subir 1 registro de Mañana, 28/09/2026'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Subir'));
      await _settle(tester);

      expect(app.uploader.uploaded, ['primera']);
      expect(find.text('1 registro subido'), findsOneWidget);
      final saved = await app.reviews.getByMessageId(
        'primera',
        ReviewRole.revisor,
      );
      expect(
        saved.fold((_) => null, (r) => r)?.estadoSync,
        EstadoSync.sincronizado,
      );
      // Ya no quedan pendientes: el botón desaparece. Seguimos en /review.
      expect(find.textContaining('Subir ·'), findsNothing);
      expect(_location(app.router), '/review');
    });

    testWidgets('no aparece mientras se trae lo subido; aparece al terminar', (
      tester,
    ) async {
      final remote = _FakeRemote()..gate = Completer<void>();
      await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0), _msg('segunda', 9, 0)]),
        records: [_record('primera')],
        remote: remote,
      );
      await _start(tester);

      expect(find.textContaining('Subir ·'), findsNothing);

      remote.gate!.complete();
      await _settle(tester);

      expect(find.text('Subir · 1 pendiente'), findsOneWidget);
    });

    // Ajuste: antes "Cerrar" desaparecía durante la subida; ahora se ve
    // deshabilitado (y Esc tampoco cierra).
    testWidgets('con una subida de esta jornada en curso, "Cerrar" se ve '
        'deshabilitado (y Esc no cierra); al terminar, se habilita', (
      tester,
    ) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      app.uploader.gate = Completer<void>();
      await _start(tester);
      expect(_cerrar, findsOneWidget);

      await tester.tap(find.text('Subir · 1 pendiente'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Subir'));
      await _settle(tester);

      expect(_cerrar, findsOneWidget);
      expect(_cerrarHabilitado(tester), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await _settle(tester);
      expect(_location(app.router), '/review');
      expect(find.text('¿Salir de la revisión?'), findsNothing);

      app.uploader.gate!.complete();
      await _settle(tester);

      expect(app.uploader.uploaded, ['primera']);
      expect(_cerrarHabilitado(tester), isTrue);
    });

    testWidgets('si la subida falla, "Cerrar" se vuelve a habilitar y el '
        'registro sigue pendiente', (tester) async {
      final app = await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      app.uploader
        ..gate = Completer<void>()
        ..failWith = const Failure.unknown(
          message: 'El registro no se pudo subir a tiempo.',
        );
      await _start(tester);

      await tester.tap(find.text('Subir · 1 pendiente'));
      await _settle(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Subir'));
      await _settle(tester);
      expect(_cerrarHabilitado(tester), isFalse);

      app.uploader.gate!.complete();
      await _settle(tester);

      expect(_cerrarHabilitado(tester), isTrue);
      expect(find.text('Subir · 1 pendiente'), findsOneWidget);
      final saved = await app.reviews.getByMessageId(
        'primera',
        ReviewRole.revisor,
      );
      expect(
        saved.fold((_) => null, (r) => r)?.estadoSync,
        EstadoSync.pendiente,
      );
    });

    testWidgets('sin pendientes no aparece; pendientes de OTRA jornada '
        'tampoco', (tester) async {
      await _pump(
        tester,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [
          _record('otra').copyWith(shift: shiftNames[Shift.afternoon1]!),
          _record('ayer', fecha: '2026-09-27'),
        ],
      );
      await _start(tester);
      expect(find.textContaining('Subir ·'), findsNothing);
    });
  });

  group('ancho < 840', () {
    testWidgets('aviso arriba, sin panel, navegación libre, "Subir" '
        'disponible y "Cerrar" siempre visible', (tester) async {
      final app = await _pump(
        tester,
        width: 700,
        repo: _FakeRepo([_msg('primera', 6, 0), _msg('segunda', 9, 0)]),
        records: [_record('segunda')],
      );
      await _start(tester);

      expect(
        find.text(
          'Gira la tablet o agranda la ventana para llenar el formulario.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ImageReviewPanel), findsNothing);
      expect(find.text('Subir · 1 pendiente'), findsOneWidget);
      // Ajuste: "primera" no tiene formulario y antes no había "Cerrar"; ahora
      // se ve (habilitado) también en angosto.
      expect(_cerrar, findsOneWidget);
      expect(_cerrarHabilitado(tester), isTrue);

      // Navegación libre aunque la actual no tenga registro.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await _settle(tester);
      expect(find.text('2 de 2'), findsOneWidget);

      // Al volver a 840 o más, el panel reaparece en la misma imagen.
      tester.view.physicalSize = const Size(1280, 900);
      await _settle(tester);
      expect(find.byType(ImageReviewPanel), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);
      expect(app.container.read(reviewSessionProvider), isNotNull);
    });

    testWidgets('con todas guardadas, "Cerrar" se ve también en angosto', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 700,
        repo: _FakeRepo([_msg('primera', 6, 0)]),
        records: [_record('primera')],
      );
      await _start(tester);
      expect(_cerrar, findsOneWidget);
    });
  });
}
