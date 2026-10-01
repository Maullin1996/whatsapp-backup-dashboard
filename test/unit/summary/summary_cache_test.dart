import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/cache/summary_cache.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/cached_group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';

JornadaSummary _summary(String chatJid) => JornadaSummary(
  chatJid: chatJid,
  groupName: chatJid,
  fechaJornada: '2026-10-05',
  shift: 'x',
  revisor: RoleSummary.sinRegistrar,
  sumador: RoleSummary.sinRegistrar,
  imagenesEnJornada: 0,
);

/// Fuente falsa: cuenta las llamadas por fecha y devuelve lo que diga
/// [next] (por defecto, un Right con un resumen marcado con el número de
/// llamada).
class _Source {
  final List<DateTime> calls = [];
  SummaryResult Function(int call)? next;
  Completer<void>? gate;

  Future<SummaryResult> Function() forDate(DateTime date) => () async {
    calls.add(date);
    final n = calls.length;
    await gate?.future;
    return next?.call(n) ?? Right([_summary('llamada-$n')]);
  };
}

class _FakeNames implements GroupNameDatasource {
  final Map<String, Either<Failure, String?>> answers;
  final List<String> calls = [];

  _FakeNames(this.answers);

  @override
  Future<Either<Failure, String?>> fetchGroupName(String chatJid) async {
    calls.add(chatJid);
    return answers[chatJid] ?? const Right(null);
  }
}

void main() {
  late DateTime now;
  late _Source source;
  late SummaryCache cache;
  final oct5 = DateTime(2026, 10, 5);
  final oct6 = DateTime(2026, 10, 6);

  setUp(() {
    now = DateTime(2026, 10, 5, 12);
    source = _Source();
    cache = SummaryCache(now: () => now);
  });

  Future<SummaryResult> get(DateTime date) =>
      cache.get(date, source.forDate(date));

  String chatOf(SummaryResult r) =>
      r.fold((f) => fail('Left: $f'), (list) => list.single.chatJid);

  test('el TTL es de 5 minutos y el máximo de 10 fechas', () {
    expect(summaryCacheTtl, const Duration(minutes: 5));
    expect(summaryCacheMaxEntries, 10);
  });

  test(
    'dentro del TTL la fuente se llama una sola vez; pasado, de nuevo',
    () async {
      expect(chatOf(await get(oct5)), 'llamada-1');

      now = now.add(const Duration(minutes: 4, seconds: 59));
      expect(chatOf(await get(oct5)), 'llamada-1');
      expect(source.calls, hasLength(1));

      now = now.add(const Duration(seconds: 1)); // edad = 5 minutos
      expect(chatOf(await get(oct5)), 'llamada-2');
      expect(source.calls, hasLength(2));
    },
  );

  test('la hora de la fecha no cuenta: mismo día, misma entrada', () async {
    await get(oct5);
    await get(DateTime(2026, 10, 5, 23, 59));

    expect(source.calls, hasLength(1));
  });

  test('fechas distintas no se mezclan', () async {
    expect(chatOf(await get(oct5)), 'llamada-1');
    expect(chatOf(await get(oct6)), 'llamada-2');
    expect(chatOf(await get(oct5)), 'llamada-1');
    expect(chatOf(await get(oct6)), 'llamada-2');
    expect(source.calls, [oct5, oct6]);
  });

  test(
    'un Left no se cachea: la siguiente consulta vuelve a la fuente',
    () async {
      source.next = (n) => n == 1
          ? const Left(Failure.firestore(message: 'sin conexión'))
          : Right([_summary('llamada-$n')]);

      expect((await get(oct5)).isLeft(), isTrue);
      expect(chatOf(await get(oct5)), 'llamada-2');
      expect(chatOf(await get(oct5)), 'llamada-2');
      expect(source.calls, hasLength(2));
    },
  );

  test('si la fuente lanza: Left, sin lanzar ni cachear', () async {
    var first = true;
    Future<SummaryResult> load() async {
      if (first) {
        first = false;
        throw StateError('boom');
      }
      return Right([_summary('ok')]);
    }

    final failed = await cache.get(oct5, load);
    expect(failed.fold((f) => f, (_) => null), isA<UnknownFailure>());
    expect(chatOf(await cache.get(oct5, load)), 'ok');
  });

  test(
    'dos consultas simultáneas de la misma fecha comparten una lectura',
    () async {
      source.gate = Completer<void>();

      final a = get(oct5);
      final b = get(oct5);
      source.gate!.complete();

      expect(chatOf(await a), 'llamada-1');
      expect(chatOf(await b), 'llamada-1');
      expect(source.calls, hasLength(1));
    },
  );

  test(
    'invalidate(fecha) fuerza una nueva lectura solo de esa fecha',
    () async {
      await get(oct5);
      await get(oct6);

      cache.invalidate(DateTime(2026, 10, 5, 8));
      expect(chatOf(await get(oct5)), 'llamada-3');
      expect(chatOf(await get(oct6)), 'llamada-2');
    },
  );

  test('invalidate durante una lectura: su resultado no se guarda', () async {
    source.gate = Completer<void>();
    final pending = get(oct5);
    cache.invalidate(oct5);
    source.gate!.complete();
    await pending;

    source.gate = null;
    expect(chatOf(await get(oct5)), 'llamada-2');
  });

  test('invalidateAll() fuerza una nueva lectura de todas', () async {
    await get(oct5);
    await get(oct6);

    cache.invalidateAll();
    await get(oct5);
    await get(oct6);

    expect(source.calls, hasLength(4));
  });

  test('al pasar de 10 fechas se descarta la más antigua', () async {
    final days = [for (var d = 1; d <= 11; d++) DateTime(2026, 10, d)];
    for (final day in days) {
      await get(day);
    }
    expect(source.calls, hasLength(11));

    // Las 10 más recientes siguen en caché…
    for (final day in days.skip(1)) {
      await get(day);
    }
    expect(source.calls, hasLength(11));

    // …y la primera se descartó.
    await get(days.first);
    expect(source.calls, hasLength(12));
  });

  group('CachedGroupNameDatasource', () {
    test(
      'un nombre encontrado se lee una sola vez en toda la sesión',
      () async {
        final inner = _FakeNames({'g1': const Right('Grupo Uno')});
        final names = CachedGroupNameDatasource(inner);

        expect(await names.fetchGroupName('g1'), const Right('Grupo Uno'));
        expect(await names.fetchGroupName('g1'), const Right('Grupo Uno'));
        expect(inner.calls, ['g1']);
      },
    );

    test('documento ausente (null): se devuelve tal cual y se vuelve a '
        'pedir', () async {
      final inner = _FakeNames({});
      final names = CachedGroupNameDatasource(inner);

      expect(
        await names.fetchGroupName('g1'),
        const Right<Failure, String?>(null),
      );
      await names.fetchGroupName('g1');
      expect(inner.calls, ['g1', 'g1']);
    });

    test('error: se devuelve tal cual y se vuelve a pedir; si después '
        'aparece, se guarda', () async {
      const failure = Failure.firestore(message: 'sin conexión');
      final inner = _FakeNames({'g1': const Left(failure)});
      final names = CachedGroupNameDatasource(inner);

      expect(
        await names.fetchGroupName('g1'),
        const Left<Failure, String?>(failure),
      );
      inner.answers['g1'] = const Right('Grupo Uno');
      expect(await names.fetchGroupName('g1'), const Right('Grupo Uno'));
      expect(await names.fetchGroupName('g1'), const Right('Grupo Uno'));
      expect(inner.calls, ['g1', 'g1']);
    });
  });
}
