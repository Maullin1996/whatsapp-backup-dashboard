import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/summary_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/repositories/firestore_summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_estado.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';

const _fecha = '2026-10-05';
final _day = DateTime(2026, 10, 5, 15, 30); // la hora no cuenta
const _g1 = 'g1@g.us';
const _g2 = 'g2@g.us';

SummaryRecord _rec(
  ReviewRole rol,
  List<int> totales, {
  String chatJid = _g1,
  Shift shift = Shift.morning,
}) => SummaryRecord(
  chatJid: chatJid,
  fechaJornada: _fecha,
  shift: shift,
  rol: rol,
  totales: totales,
);

class _FakeRecords implements SummaryRecordsDatasource {
  List<SummaryRecord> records = [];
  Failure? failure;
  final List<String> requested = [];

  @override
  Future<Either<Failure, List<SummaryRecord>>> fetchByFechaJornada(
    String fechaJornada,
  ) async {
    requested.add(fechaJornada);
    final failure = this.failure;
    return failure != null ? Left(failure) : Right(records);
  }
}

class _FakeCounts implements ShiftImageCountsDatasource {
  List<ShiftImageCount> counts = [];
  Failure? failure;
  final List<String> requested = [];

  @override
  Future<Either<Failure, List<ShiftImageCount>>> fetchByShiftDate(
    String shiftDate,
  ) async {
    requested.add(shiftDate);
    final failure = this.failure;
    return failure != null ? Left(failure) : Right(counts);
  }
}

class _FakeGroupNames implements GroupNameDatasource {
  Map<String, String> names = {};
  Set<String> failing = {};
  bool throws = false;

  @override
  Future<Either<Failure, String?>> fetchGroupName(String chatJid) async {
    if (throws) throw StateError('se cayó');
    if (failing.contains(chatJid)) {
      return const Left(Failure.firestore(message: 'sin conexión'));
    }
    return Right(names[chatJid]);
  }
}

void main() {
  late _FakeRecords records;
  late _FakeCounts counts;
  late _FakeGroupNames groupNames;
  late FirestoreSummaryRepository repo;

  setUp(() {
    records = _FakeRecords();
    counts = _FakeCounts();
    groupNames = _FakeGroupNames()
      ..names = {_g1: 'Grupo Uno', _g2: 'Grupo Dos'};
    repo = FirestoreSummaryRepository(
      records: records,
      counts: counts,
      groupNames: groupNames,
    );
  });

  Future<List<JornadaSummary>> summaries() async =>
      (await repo.getJornadaSummaries(
        _day,
      )).fold((f) => fail('Left: $f'), (list) => list);

  test(
    'pide registros y contadores del día con fechaJornadaDe (yyyy-MM-dd)',
    () async {
      await repo.getJornadaSummaries(_day);

      expect(records.requested, [_fecha]);
      expect(counts.requested, [_fecha]);
    },
  );

  test('día vacío: lista vacía', () async {
    expect(await summaries(), isEmpty);
  });

  group('agregación por rol', () {
    test('varios registros y comprobantes: cantidades, totales y estado '
        'cuadra', () async {
      records.records = [
        _rec(ReviewRole.revisor, [1000, 2000]),
        _rec(ReviewRole.revisor, [3000]),
        _rec(ReviewRole.sumador, [3000]),
        _rec(ReviewRole.sumador, [2500, 500]),
      ];
      counts.counts = [
        const ShiftImageCount(chatJid: _g1, shift: Shift.morning, lastIndex: 3),
      ];

      final s = (await summaries()).single;

      expect(
        s.revisor,
        const RoleSummary(
          registrado: true,
          cantidadImagenes: 2,
          cantidadTickets: 3,
          totalSuma: 6000,
        ),
      );
      expect(
        s.sumador,
        const RoleSummary(
          registrado: true,
          cantidadImagenes: 2,
          cantidadTickets: 3,
          totalSuma: 6000,
        ),
      );
      expect(s.estado, const JornadaEstado.cuadra());
      expect(s.imagenesEnJornada, 3);
      expect(s.chatJid, _g1);
      expect(s.groupName, 'Grupo Uno');
      expect(s.fechaJornada, _fecha);
      expect(s.shift, shiftNames[Shift.morning]);
    });

    test('sumas distintas: descuadre con la diferencia', () async {
      records.records = [
        _rec(ReviewRole.revisor, [5000]),
        _rec(ReviewRole.sumador, [4000]),
      ];

      final s = (await summaries()).single;

      expect(s.estado, const JornadaEstado.descuadre(diferencia: 1000));
    });

    test(
      'un rol sin registros: sinRegistrar y pendiente con ese rol',
      () async {
        records.records = [
          _rec(ReviewRole.revisor, [1000]),
        ];

        final s = (await summaries()).single;

        expect(s.sumador, RoleSummary.sinRegistrar);
        expect(s.revisor.registrado, isTrue);
        expect(
          s.estado,
          const JornadaEstado.pendiente(faltan: {ReviewRole.sumador}),
        );
      },
    );

    test(
      'Sumador (sin números): los tickets y totales cuentan igual',
      () async {
        records.records = [
          _rec(ReviewRole.sumador, [700, 300, 1000]),
        ];

        final s = (await summaries()).single;

        expect(s.sumador.cantidadImagenes, 1);
        expect(s.sumador.cantidadTickets, 3);
        expect(s.sumador.totalSuma, 2000);
      },
    );
  });

  test('grupo con contador y sin registros: ambos sinRegistrar, con el '
      'contador', () async {
    counts.counts = [
      const ShiftImageCount(
        chatJid: _g2,
        shift: Shift.afternoon1,
        lastIndex: 7,
      ),
    ];

    final s = (await summaries()).single;

    expect(s.revisor, RoleSummary.sinRegistrar);
    expect(s.sumador, RoleSummary.sinRegistrar);
    expect(s.imagenesEnJornada, 7);
    expect(s.shift, shiftNames[Shift.afternoon1]);
    expect(
      s.estado,
      const JornadaEstado.pendiente(
        faltan: {ReviewRole.revisor, ReviewRole.sumador},
      ),
    );
  });

  test('grupo con registros y sin contador: imagenesEnJornada 0', () async {
    records.records = [
      _rec(ReviewRole.revisor, [1000]),
    ];

    expect((await summaries()).single.imagenesEnJornada, 0);
  });

  test('dos jornadas del mismo grupo y día quedan separadas', () async {
    records.records = [
      _rec(ReviewRole.revisor, [1000]),
      _rec(ReviewRole.revisor, [9000], shift: Shift.night1),
    ];
    counts.counts = [
      const ShiftImageCount(chatJid: _g1, shift: Shift.night1, lastIndex: 4),
    ];

    final list = await summaries();

    expect(list, hasLength(2));
    expect(list[0].shift, shiftNames[Shift.morning]);
    expect(list[0].revisor.totalSuma, 1000);
    expect(list[0].imagenesEnJornada, 0);
    expect(list[1].shift, shiftNames[Shift.night1]);
    expect(list[1].revisor.totalSuma, 9000);
    expect(list[1].imagenesEnJornada, 4);
  });

  test('orden: por grupo (nombre) y, dentro, por jornada', () async {
    records.records = [
      _rec(ReviewRole.revisor, [1], chatJid: _g1, shift: Shift.night1),
      _rec(ReviewRole.revisor, [1], chatJid: _g2, shift: Shift.afternoon2),
      _rec(ReviewRole.revisor, [1], chatJid: _g1, shift: Shift.morning),
    ];
    counts.counts = [
      const ShiftImageCount(chatJid: _g2, shift: Shift.morning, lastIndex: 1),
    ];

    final list = await summaries();

    expect(
      [for (final s in list) (s.groupName, s.shift)],
      [
        ('Grupo Dos', shiftNames[Shift.morning]),
        ('Grupo Dos', shiftNames[Shift.afternoon2]),
        ('Grupo Uno', shiftNames[Shift.morning]),
        ('Grupo Uno', shiftNames[Shift.night1]),
      ],
    );
  });

  group('groupName', () {
    test('documento ausente: el chatJid', () async {
      groupNames.names = {};
      records.records = [
        _rec(ReviewRole.revisor, [1]),
      ];

      expect((await summaries()).single.groupName, _g1);
    });

    test(
      'la lectura del nombre falla: el chatJid, y el Resumen sigue',
      () async {
        groupNames.failing = {_g1};
        records.records = [
          _rec(ReviewRole.revisor, [1]),
          _rec(ReviewRole.revisor, [1], chatJid: _g2),
        ];

        final list = await summaries();

        expect(
          {for (final s in list) s.chatJid: s.groupName},
          {_g1: _g1, _g2: 'Grupo Dos'},
        );
      },
    );

    test('el datasource de nombres lanza: el chatJid, sin tumbar el '
        'Resumen', () async {
      groupNames.throws = true;
      records.records = [
        _rec(ReviewRole.revisor, [1]),
      ];

      expect((await summaries()).single.groupName, _g1);
    });
  });

  group('fallos de lectura', () {
    test('registros Left: el repositorio devuelve ese Left', () async {
      records.failure = const Failure.unauthorized();
      counts.counts = [
        const ShiftImageCount(chatJid: _g1, shift: Shift.morning, lastIndex: 1),
      ];

      expect(
        await repo.getJornadaSummaries(_day),
        const Left<Failure, List<JornadaSummary>>(Failure.unauthorized()),
      );
    });

    test('contadores Left: el repositorio devuelve ese Left', () async {
      counts.failure = const Failure.firestore(message: 'sin conexión');
      records.records = [
        _rec(ReviewRole.revisor, [1]),
      ];

      expect(
        await repo.getJornadaSummaries(_day),
        const Left<Failure, List<JornadaSummary>>(
          Failure.firestore(message: 'sin conexión'),
        ),
      );
    });

    test('formato inesperado (Left del datasource, con el id): llega tal '
        'cual, sin omitir nada', () async {
      const failure = Failure.unknown(
        message: 'El registro m1_revisor tiene un formato inesperado.',
      );
      records.failure = failure;

      expect(
        await repo.getJornadaSummaries(_day),
        const Left<Failure, List<JornadaSummary>>(failure),
      );
    });
  });
}
