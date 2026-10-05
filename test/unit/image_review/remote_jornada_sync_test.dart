import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_local_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/datasources/review_remote_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/models/image_review_record_model.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/local_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/sync/remote_jornada_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

const _chat = 'chat@g.us';
const _fecha = '2026-01-15';
const _rol = ReviewRole.revisor;

ImageReviewRecord _record(
  String messageId, {
  int total = 9000,
  EstadoSync estadoSync = EstadoSync.sincronizado,
  String registradoPor = 'revisor@example.com',
}) => ImageReviewRecord(
  messageId: messageId,
  chatJid: _chat,
  shift: shiftNames[Shift.morning]!,
  rol: _rol,
  storagePath: 'img_$messageId.png',
  fechaJornada: _fecha,
  messageTimestamp: 1788489942000,
  form: ImageReviewForm(
    codigo: 'A1',
    comprobantes: [
      Comprobante(numeros: const ['0123'], total: total),
    ],
  ),
  registradoEn: DateTime(2026, 1, 15, 8),
  registradoPor: registradoPor,
  estadoSync: estadoSync,
);

/// Lectura falsa: devuelve [result] y cuenta las llamadas.
class _FakeRemote implements ReviewRemoteRecordsDatasource {
  Either<Failure, List<ImageReviewRecordModel>> result = const Right([]);
  int calls = 0;

  @override
  Future<Either<Failure, List<ImageReviewRecordModel>>> fetchJornada({
    required String chatJid,
    required String fechaJornada,
    required Shift shift,
    required ReviewRole rol,
  }) async {
    calls++;
    return result;
  }
}

void main() {
  late Directory dir;
  late LocalImageReviewRepository repo;
  late _FakeRemote remote;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('remote_sync_');
    final ds = (await ReviewLocalDatasource.open(
      path: dir.path,
    )).getOrElse(() => fail('no se pudo abrir el almacenamiento'));
    repo = LocalImageReviewRepository(ds, uid: 'uid-a');
    remote = _FakeRemote();
  });

  tearDown(() async {
    await Hive.close();
    await dir.delete(recursive: true);
  });

  void remoteHas(List<ImageReviewRecord> records) => remote.result = Right([
    for (final r in records) ImageReviewRecordModel(r),
  ]);

  Future<Either<Failure, RemoteJornadaSyncResult>> sync(
    List<String> jornadaIds,
  ) => syncJornadaFromRemote(
    remote: remote,
    repository: repo,
    chatJid: _chat,
    fechaJornada: _fecha,
    shift: Shift.morning,
    rol: _rol,
    jornadaMessageIds: jornadaIds,
  );

  Future<ImageReviewRecord?> local(String id) async =>
      (await repo.getByMessageId(id, _rol)).getOrElse(() => fail('Left'));

  Future<List<String>> pendingIds() async => [
    for (final r in (await repo.getPending(
      chatJid: _chat,
      fechaJornada: _fecha,
      shift: shiftNames[Shift.morning]!,
      rol: _rol,
    )).getOrElse(() => fail('Left')))
      r.messageId,
  ];

  RemoteJornadaSyncResult right(Either<Failure, RemoteJornadaSyncResult> e) =>
      e.getOrElse(() => fail('se esperaba Right: $e'));

  test(
    'sin nada local: lo de Firebase queda en local como sincronizado',
    () async {
      remoteHas([_record('m1')]);

      final result = right(await sync(['m1', 'm2']));

      final r = await local('m1');
      expect(r?.estadoSync, EstadoSync.sincronizado);
      expect(r?.form.comprobantes.single.total, 9000);
      expect(await local('m2'), isNull);
      expect(await pendingIds(), isEmpty);
      expect(result, (escritos: 1, pendientesConservados: 0, borrados: 0));
    },
  );

  test('un pendiente local gana y no se toca', () async {
    await repo.save(
      _record('m1', total: 5000, estadoSync: EstadoSync.pendiente),
    );
    remoteHas([_record('m1', total: 9000)]);

    final result = right(await sync(['m1']));

    final r = await local('m1');
    expect(r?.estadoSync, EstadoSync.pendiente);
    expect(r?.form.comprobantes.single.total, 5000);
    expect(await pendingIds(), ['m1']);
    expect(result, (escritos: 0, pendientesConservados: 1, borrados: 0));
  });

  test(
    'un sincronizado local que difiere se reemplaza por lo de Firebase',
    () async {
      await repo.save(_record('m1', total: 5000));
      remoteHas([
        _record('m1', total: 9000, registradoPor: 'otra@example.com'),
      ]);

      right(await sync(['m1']));

      final r = await local('m1');
      expect(r?.estadoSync, EstadoSync.sincronizado);
      expect(r?.form.comprobantes.single.total, 9000);
      expect(r?.registradoPor, 'otra@example.com');
    },
  );

  test('un sincronizado local que no está en Firebase se borra', () async {
    await repo.save(_record('m1'));
    await repo.save(_record('m2'));
    remoteHas([_record('m1')]);

    final result = right(await sync(['m1', 'm2']));

    expect(await local('m1'), isNotNull);
    expect(await local('m2'), isNull);
    expect(result.borrados, 1);
  });

  test('un pendiente local que no está en Firebase se conserva', () async {
    await repo.save(_record('m2', estadoSync: EstadoSync.pendiente));
    remoteHas([]);

    final result = right(await sync(['m2']));

    expect((await local('m2'))?.estadoSync, EstadoSync.pendiente);
    expect(await pendingIds(), ['m2']);
    expect(result.borrados, 0);
  });

  test('solo borra los de las imágenes de esa jornada', () async {
    await repo.save(_record('m1'));
    await repo.save(_record('otra-jornada'));
    remoteHas([]);

    right(await sync(['m1']));

    expect(await local('m1'), isNull);
    expect(await local('otra-jornada'), isNotNull);
  });

  test('un fallo de lectura no escribe ni borra nada', () async {
    await repo.save(_record('m1'));
    await repo.save(_record('m2', estadoSync: EstadoSync.pendiente));
    remote.result = const Left(Failure.unauthorized());

    final result = await sync(['m1', 'm2']);

    expect(result.isLeft(), isTrue);
    expect(remote.calls, 1);
    expect((await local('m1'))?.estadoSync, EstadoSync.sincronizado);
    expect((await local('m2'))?.estadoSync, EstadoSync.pendiente);
  });

  test('una imagen sin registro en ningún lado no hace nada', () async {
    remoteHas([]);

    final result = right(await sync(['m1']));

    expect(await local('m1'), isNull);
    expect(result, (escritos: 0, pendientesConservados: 0, borrados: 0));
  });
}
