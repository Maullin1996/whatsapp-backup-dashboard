import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/message_context_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/revisor_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/repositories/firestore_matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';

const _fecha = '2026-10-05'; // lunes
final _monday = DateTime(2026, 10, 5, 15, 30); // la hora no cuenta
final _sunday = DateTime(2026, 10, 4);
const _g1 = 'g1@g.us';
const _g2 = 'g2@g.us';

final _names = shiftNamesAt(DateTime(2026, 10, 5).millisecondsSinceEpoch);
String _label(Shift s) => _names[s] ?? shiftNames[s]!;

RevisorRecord _rec(
  String messageId,
  List<String> numeros, {
  String chatJid = _g1,
  Shift shift = Shift.morning,
}) => RevisorRecord(
  chatJid: chatJid,
  shift: shift,
  messageId: messageId,
  storagePath: 'img/$messageId.jpg',
  fechaJornada: _fecha,
  numeros: numeros,
);

class _FakeWinners implements WinningNumbersDatasource {
  List<String> numbers = [];
  Failure? failure;
  final List<String> requested = [];

  @override
  Future<Either<Failure, List<String>>> fetchByFecha(String fecha) async {
    requested.add(fecha);
    final failure = this.failure;
    return failure != null ? Left(failure) : Right(numbers);
  }
}

class _FakeRecords implements RevisorRecordsDatasource {
  List<RevisorRecord> records = [];
  Failure? failure;
  final List<String> requested = [];

  @override
  Future<Either<Failure, List<RevisorRecord>>> fetchByFechaJornada(
    String fechaJornada,
  ) async {
    requested.add(fechaJornada);
    final failure = this.failure;
    return failure != null ? Left(failure) : Right(records);
  }
}

class _FakeMessages implements MessageContextDatasource {
  final Map<String, MessageContext> byId = {};
  final Map<String, Failure> failing = {};
  final List<String> requested = [];

  @override
  Future<Either<Failure, MessageContext>> fetchById(String messageId) async {
    requested.add(messageId);
    final failure = failing[messageId];
    if (failure != null) return Left(failure);
    final context = byId[messageId];
    return context != null
        ? Right(context)
        : Left(Failure.unknown(message: 'El mensaje $messageId no existe.'));
  }
}

class _FakeGroupNames implements GroupNameDatasource {
  Map<String, String> names = {};
  Set<String> failing = {};
  final List<String> requested = [];

  @override
  Future<Either<Failure, String?>> fetchGroupName(String chatJid) async {
    requested.add(chatJid);
    if (failing.contains(chatJid)) {
      return const Left(Failure.firestore(message: 'sin conexión'));
    }
    return Right(names[chatJid]);
  }
}

void main() {
  late _FakeWinners winners;
  late _FakeRecords records;
  late _FakeMessages messages;
  late _FakeGroupNames groupNames;
  late FirestoreMatchesRepository repo;

  setUp(() {
    winners = _FakeWinners();
    records = _FakeRecords();
    messages = _FakeMessages();
    for (final id in ['m1', 'm2', 'm3', 'm4']) {
      messages.byId[id] = (
        senderName: 'Remitente $id',
        localTime: '08:1${id[1]}',
      );
    }
    groupNames = _FakeGroupNames()
      ..names = {_g1: 'Grupo Uno', _g2: 'Grupo Dos'};
    repo = FirestoreMatchesRepository(
      winners: winners,
      records: records,
      messages: messages,
      groupNames: groupNames,
    );
  });

  Future<DayMatches> day([DateTime? date]) async => (await repo.getMatches(
    date ?? _monday,
  )).fold((f) => fail('Left: $f'), (d) => d);

  Future<Failure> failure() async => (await repo.getMatches(
    _monday,
  )).fold((f) => f, (_) => fail('se esperaba Left'));

  List<MatchEntry> allMatches(DayMatches d) => [
    for (final j in d.jornadas) ...j.matches,
  ];

  test('coincidencia simple: entrada con senderName, localTime y groupName '
      'completos, en su jornada', () async {
    winners.numbers = ['4521'];
    records.records = [
      _rec('m1', ['4521', '7788']),
    ];

    final d = await day();

    expect(d.fechaJornada, _fecha);
    expect(winners.requested, [_fecha]);
    expect(records.requested, [_fecha]);
    final morning = d.jornadas.firstWhere(
      (j) => j.shift == _label(Shift.morning),
    );
    expect(morning.matches, [
      MatchEntry(
        numero: '4521',
        messageId: 'm1',
        chatJid: _g1,
        groupName: 'Grupo Uno',
        senderName: 'Remitente m1',
        localTime: '08:11',
        storagePath: 'img/m1.jpg',
        shift: _label(Shift.morning),
        fechaJornada: _fecha,
      ),
    ]);
  });

  test(
    '"0123" y "123" no coinciden; los espacios alrededor se ignoran',
    () async {
      winners.numbers = [' 0123 '];
      records.records = [
        _rec('m1', ['123']),
        _rec('m2', ['0123 ']),
      ];

      final matches = allMatches(await day());

      expect(matches.map((m) => m.messageId), ['m2']);
      expect(matches.single.numero, '0123 '); // tal cual lo anotó el Revisor
    },
  );

  test('un ganador en dos registros: dos entradas; un registro con dos '
      'comprobantes: solo el número que coincide', () async {
    winners.numbers = ['5566'];
    records.records = [
      // m1: dos comprobantes aplanados ('5566' y '1111').
      _rec('m1', ['5566', '1111']),
      _rec('m2', ['5566'], chatJid: _g2),
    ];

    final matches = allMatches(await day());

    expect(matches, hasLength(2));
    expect(matches.map((m) => m.numero).toSet(), {'5566'});
    expect(matches.map((m) => m.messageId).toSet(), {'m1', 'm2'});
  });

  test('los ganadores valen para todas las jornadas: la misma lista en cada '
      'una', () async {
    winners.numbers = ['4521', '9999'];
    records.records = [
      _rec('m1', ['4521'], shift: Shift.night1),
    ];

    final d = await day();

    for (final j in d.jornadas) {
      expect(j.winningNumbers, ['4521', '9999'], reason: j.shift);
    }
    final night1 = d.jornadas.firstWhere(
      (j) => j.shift == _label(Shift.night1),
    );
    expect(night1.matches.single.messageId, 'm1');
  });

  test('día sin ganadores: las jornadas del día con listas vacías y NO se '
      'leen registros', () async {
    final d = await day();

    expect(records.requested, isEmpty);
    expect(messages.requested, isEmpty);
    expect(d.jornadas.map((j) => j.shift), [
      for (final s in [
        Shift.morning,
        Shift.afternoon1,
        Shift.afternoon2,
        Shift.night1,
      ])
        _label(s),
    ]);
    for (final j in d.jornadas) {
      expect(j.winningNumbers, isEmpty);
      expect(j.matches, isEmpty);
    }
  });

  test('domingo: solo holiday', () async {
    final d = await day(_sunday);

    expect(d.fechaJornada, '2026-10-04');
    expect(d.jornadas.map((j) => j.shift), [
      shiftNamesAt(_sunday.millisecondsSinceEpoch)[Shift.holiday],
    ]);
  });

  test('jornada con registros pero sin coincidencias: aparece con matches '
      'vacíos; night2 solo si tiene registros', () async {
    winners.numbers = ['4521'];
    records.records = [
      _rec('m1', ['1111'], shift: Shift.afternoon2),
    ];

    var d = await day();
    expect(
      d.jornadas.map((j) => j.shift),
      isNot(contains(_label(Shift.night2))),
    );
    final afternoon2 = d.jornadas.firstWhere(
      (j) => j.shift == _label(Shift.afternoon2),
    );
    expect(afternoon2.matches, isEmpty);

    records.records = [
      _rec('m1', ['4521'], shift: Shift.night2),
    ];
    d = await day();
    expect(d.jornadas.map((j) => j.shift).toList(), [
      _label(Shift.morning),
      _label(Shift.afternoon1),
      _label(Shift.afternoon2),
      _label(Shift.night1),
      _label(Shift.night2),
    ]);
    expect(d.jornadas.last.matches.single.messageId, 'm1');
  });

  test(
    'solo se leen mensajes y grupos de las coincidentes, una vez por id',
    () async {
      winners.numbers = ['4521', '5566'];
      records.records = [
        _rec('m1', ['4521', '5566']), // dos coincidencias, un mensaje
        _rec('m2', ['4521']),
        _rec('m3', ['0000'], chatJid: _g2), // sin coincidencia
      ];

      final matches = allMatches(await day());

      expect(matches, hasLength(3));
      expect(messages.requested, unorderedEquals(['m1', 'm2']));
      expect(groupNames.requested, [_g1]);
    },
  );

  test('grupo sin documento en group_stats: groupName = chatJid', () async {
    winners.numbers = ['4521'];
    records.records = [
      _rec('m1', ['4521'], chatJid: 'sin-nombre@g.us'),
    ];

    expect(allMatches(await day()).single.groupName, 'sin-nombre@g.us');
  });

  test('falla la lectura del grupo: Left', () async {
    winners.numbers = ['4521'];
    records.records = [
      _rec('m1', ['4521']),
    ];
    groupNames.failing = {_g1};

    expect(await failure(), isA<FirestoreFailure>());
  });

  test('falla la lectura de un mensaje o no existe: Left con el id', () async {
    winners.numbers = ['4521'];
    records.records = [
      _rec('m1', ['4521']),
    ];
    messages.failing['m1'] = const Failure.unknown(
      message: 'Error inesperado al leer el mensaje m1.',
    );
    expect((await failure()).message, contains('m1'));

    messages.failing.clear();
    messages.byId.remove('m1');
    final f = await failure();
    expect(f.message, contains('m1'));
    expect(f.message, contains('no existe'));
  });

  test('falla la lectura de ganadores o de registros (p. ej. un registro '
      'malformado): Left tal cual', () async {
    winners.failure = const Failure.firestore(message: 'sin índice');
    expect(await failure(), const Failure.firestore(message: 'sin índice'));

    winners.failure = null;
    winners.numbers = ['4521'];
    const malformed = Failure.unknown(
      message: 'El registro m9_revisor tiene una jornada inválida ("x").',
    );
    records.failure = malformed;
    expect(await failure(), malformed);
  });

  test('dos jornadas del mismo grupo y fecha quedan separadas', () async {
    winners.numbers = ['4521'];
    records.records = [
      _rec('m1', ['4521'], shift: Shift.morning),
      _rec('m2', ['4521'], shift: Shift.night1),
    ];

    final d = await day();

    final morning = d.jornadas.firstWhere(
      (j) => j.shift == _label(Shift.morning),
    );
    final night1 = d.jornadas.firstWhere(
      (j) => j.shift == _label(Shift.night1),
    );
    expect(morning.matches.single.messageId, 'm1');
    expect(night1.matches.single.messageId, 'm2');
  });

  test('orden dentro de la jornada: groupName, chatJid, messageId y '
      'número', () async {
    winners.numbers = ['1', '2'];
    records.records = [
      _rec('m4', ['2', '1'], chatJid: _g1), // Grupo Uno
      _rec('m3', ['1'], chatJid: _g2), // Grupo Dos
      _rec('m1', ['2'], chatJid: _g1),
    ];

    final matches = allMatches(await day());

    expect(
      matches.map((m) => '${m.groupName}|${m.messageId}|${m.numero}').toList(),
      ['Grupo Dos|m3|1', 'Grupo Uno|m1|2', 'Grupo Uno|m4|1', 'Grupo Uno|m4|2'],
    );
  });

  test('si un datasource lanza (rompiendo su contrato): Left, nunca '
      'relanza', () async {
    final broken = FirestoreMatchesRepository(
      winners: _ThrowingWinners(),
      records: records,
      messages: messages,
      groupNames: groupNames,
    );

    final result = await broken.getMatches(_monday);

    expect(result.fold((f) => f, (_) => null), isA<UnknownFailure>());
  });
}

class _ThrowingWinners implements WinningNumbersDatasource {
  @override
  Future<Either<Failure, List<String>>> fetchByFecha(String fecha) =>
      throw StateError('se cayó');
}
