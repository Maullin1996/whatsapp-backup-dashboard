import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_upload_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/sync/firestore_review_uploader.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/review_upload_notifier.dart';

const _shift = 'Jornada Mañana (06:00 – 10:54)';
const _jornadaPath = 'image_reviews/c1@g.us/jornadas/2026-01-15_morning';

ImageReviewRecord _record(
  String id, {
  ReviewRole rol = ReviewRole.revisor,
  String shift = _shift,
  int? messageTimestamp = 1788489942000,
}) => ImageReviewRecord(
  messageId: id,
  chatJid: 'c1@g.us',
  shift: shift,
  rol: rol,
  storagePath: 'img_$id.png',
  fechaJornada: '2026-01-15',
  messageTimestamp: messageTimestamp,
  form: ImageReviewForm(
    comprobantes: [
      Comprobante(
        codigo: 'A1',
        numeros: rol == ReviewRole.revisor ? const ['0123'] : const [],
        total: 1000,
      ),
    ],
  ),
  registradoEn: DateTime.utc(2026, 1, 15, 8),
  registradoPor: 'a@x.com',
);

/// Datasource falso en memoria: guarda cada documento por su ruta completa
/// (reemplazándolo, como el contrato) y registra cada llamada.
class _FakeReviewUploadDatasource implements ReviewUploadDatasource {
  final Map<String, Map<String, dynamic>> documents = {};
  final List<(List<String>, Map<String, dynamic>)> calls = [];

  /// Si no es null, se devuelve en vez de guardar.
  Failure? failWith;

  /// Si es true, lanza (rompe el contrato) en vez de guardar.
  bool throws = false;

  @override
  Future<Either<Failure, Unit>> setDocument(
    List<String> pathSegments,
    Map<String, dynamic> data,
  ) async {
    calls.add((pathSegments, data));
    if (throws) throw StateError('se cayó el datasource');
    if (failWith != null) return Left(failWith!);
    documents[pathSegments.join('/')] = Map.of(data);
    return const Right(unit);
  }
}

void main() {
  late _FakeReviewUploadDatasource datasource;
  late FirestoreReviewUploader uploader;

  setUp(() {
    datasource = _FakeReviewUploadDatasource();
    uploader = FirestoreReviewUploader(datasource);
  });

  test('éxito: llama una vez con la ruta y los datos del registro (con '
      'shiftKey) y devuelve Right', () async {
    final record = _record('m1');

    final result = await uploader.upload(record);

    expect(result, const Right<Failure, Unit>(unit));
    expect(datasource.calls, hasLength(1));
    final (segments, data) = datasource.calls.single;
    expect(segments, [
      'image_reviews',
      'c1@g.us',
      'jornadas',
      '2026-01-15_morning',
      'registros',
      'm1_revisor',
    ]);
    final expected = ImageReviewRecordModel(
      record,
    ).toUploadDocument().fold((f) => fail('Left: $f'), (d) => d);
    expect(segments, expected.pathSegments);
    expect(data, expected.data);
    expect(data['shiftKey'], 'morning');
    expect(data['messageTimestamp'], 1788489942000);
    expect(data.containsKey('registradoEn'), isTrue);
  });

  test('sin messageTimestamp (registro de antes): Left sin llamar al '
      'datasource', () async {
    final result = await uploader.upload(_record('m1', messageTimestamp: null));

    final failure = result.fold((f) => f, (_) => fail('se esperaba Left'));
    expect(failure, isA<UnknownFailure>());
    expect(failure.message, contains('m1'));
    expect(datasource.calls, isEmpty);
    expect(datasource.documents, isEmpty);
  });

  test('idempotente: subir el mismo registro dos veces deja un solo '
      'documento', () async {
    final record = _record('m1');

    await uploader.upload(record);
    await uploader.upload(record);

    expect(datasource.calls, hasLength(2));
    expect(datasource.documents.keys, ['$_jornadaPath/registros/m1_revisor']);
  });

  test('Revisor y Sumador de la misma imagen: mismo prefijo de jornada, ids '
      'distintos, dos documentos', () async {
    await uploader.upload(_record('m1'));
    await uploader.upload(_record('m1', rol: ReviewRole.sumador));

    expect(
      datasource.documents.keys,
      unorderedEquals([
        '$_jornadaPath/registros/m1_revisor',
        '$_jornadaPath/registros/m1_sumador',
      ]),
    );
    final (revisor, _) = datasource.calls.first;
    final (sumador, _) = datasource.calls.last;
    expect(revisor.take(5), sumador.take(5));
    expect(revisor.last, isNot(sumador.last));
  });

  test(
    'el datasource devuelve Left: el uploader devuelve ese mismo Left',
    () async {
      const failure = Failure.firestore(message: 'sin conexión');
      datasource.failWith = failure;

      final result = await uploader.upload(_record('m1'));

      expect(result, const Left<Failure, Unit>(failure));
      expect(datasource.documents, isEmpty);
    },
  );

  test('el datasource lanza: Left(Failure.unknown) sin relanzar', () async {
    datasource.throws = true;

    final result = await uploader.upload(_record('m1'));

    final failure = result.fold((f) => f, (_) => fail('se esperaba Left'));
    expect(failure, isA<UnknownFailure>());
    expect(failure.message, contains('m1'));
    expect(datasource.calls, hasLength(1));
  });

  for (final (caso, shift) in [
    ('fuera de jornada', 'Fuera de las jornadas'),
    ('etiqueta desconocida', 'Jornada Madrugada'),
  ]) {
    test('$caso: Left sin llamar al datasource', () async {
      final result = await uploader.upload(_record('m1', shift: shift));

      expect(
        result.fold((f) => f, (_) => fail('se esperaba Left')),
        isA<UnknownFailure>(),
      );
      expect(datasource.calls, isEmpty);
    });
  }

  group('con ReviewUploadNotifier', () {
    late InMemoryImageReviewRepository repo;

    const jornada = (
      chatJid: 'c1@g.us',
      fechaJornada: '2026-01-15',
      shift: _shift,
    );

    ProviderContainer makeContainer() {
      final c = ProviderContainer(
        overrides: [
          imageReviewRepositoryProvider.overrideWithValue(repo),
          reviewUploaderProvider.overrideWithValue(uploader),
          currentReviewRoleProvider.overrideWithValue(ReviewRole.revisor),
          reviewerUidProvider.overrideWithValue('uid-a'),
          reviewerEmailProvider.overrideWithValue('a@x.com'),
        ],
      );
      addTearDown(c.dispose);
      c
          .read(activeChatProvider.notifier)
          .select(
            Chat(
              chatJid: 'c1@g.us',
              groupName: 'g',
              lastMessageAt: 0,
              totalImages: 0,
            ),
          );
      return c;
    }

    Future<EstadoSync> estado(String id) async => (await repo.getByMessageId(
      id,
      ReviewRole.revisor,
    )).fold((_) => fail('Left'), (r) => r!.estadoSync);

    setUp(() => repo = InMemoryImageReviewRepository());

    test('éxito: queda escrito y marcado sincronizado', () async {
      await repo.save(_record('m1'));
      final c = makeContainer();

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(jornada);

      expect(outcome!.subidos, 1);
      expect(outcome.todoSubido, isTrue);
      expect(await estado('m1'), EstadoSync.sincronizado);
      expect(datasource.documents.keys, ['$_jornadaPath/registros/m1_revisor']);
    });

    test('fallo del datasource: el registro sigue pendiente', () async {
      await repo.save(_record('m1'));
      datasource.failWith = const Failure.firestore(message: 'sin conexión');
      final c = makeContainer();

      final outcome = await c
          .read(reviewUploadProvider.notifier)
          .upload(jornada);

      expect(outcome!.subidos, 0);
      expect(outcome.fallidos, 1);
      expect(await estado('m1'), EstadoSync.pendiente);
      expect(datasource.documents, isEmpty);
    });
  });
}
