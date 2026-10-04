import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/helpers/jornada_images.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/jornada_images_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/message.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/messages_page.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/repositories/messages_repository.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_repository_provider.dart';

/// Mensaje con la etiqueta de jornada que calcularía `toDomain` para [at]
/// (hora local).
Message _msg(
  String id,
  DateTime at, {
  bool image = true,
  String chatJid = 'c1',
  int? index,
}) => Message(
  id: id,
  chatJid: chatJid,
  senderName: 'Ana',
  hasMedia: image,
  storagePath: image ? 'img/$id.jpg' : null,
  messageTimestamp: at.millisecondsSinceEpoch,
  localTime: '',
  shift: shiftViewerLabel(at),
  messageDate: '',
  shiftImageIndex: index,
);

/// Repositorio falso: devuelve los mensajes del rango pedido en páginas de
/// `limit` (más nuevo primero, como Firestore) y la escucha sale de [live].
class _FakeRepo implements MessagesRepository {
  final List<Message> messages;
  final StreamController<Message> live = StreamController<Message>();
  final List<({int from, int to, int limit, Object? cursor})> pageCalls = [];
  final List<int> listenCalls = [];
  Failure? failure;

  _FakeRepo(this.messages);

  @override
  Future<Either<Failure, MessagesPage>> fetchByDateRange({
    required String chatJid,
    required int fromTimestamp,
    required int toTimestamp,
    int limit = 50,
    Object? cursor,
  }) async {
    pageCalls.add((
      from: fromTimestamp,
      to: toTimestamp,
      limit: limit,
      cursor: cursor,
    ));
    final failure = this.failure;
    if (failure != null) return Left(failure);
    final inRange =
        messages
            .where(
              (m) =>
                  m.chatJid == chatJid &&
                  m.messageTimestamp >= fromTimestamp &&
                  m.messageTimestamp < toTimestamp,
            )
            .toList()
          ..sort((a, b) => b.messageTimestamp.compareTo(a.messageTimestamp));
    final start = (cursor as int?) ?? 0;
    final page = inRange.skip(start).take(limit).toList();
    return Right(
      MessagesPage(
        items: page,
        nextCursor: page.isEmpty ? null : start + page.length,
      ),
    );
  }

  @override
  Stream<Message> listenNewMessages({
    required String chatJid,
    required int afterTimestamp,
  }) {
    listenCalls.add(afterTimestamp);
    return live.stream;
  }

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

/// Escucha el provider y devuelve su último valor cuando cambia.
Future<List<ImageViewItem>> _next(
  ProviderContainer container,
  JornadaImagesKey key,
) {
  final completer = Completer<List<ImageViewItem>>();
  late final ProviderSubscription<AsyncValue<List<ImageViewItem>>> sub;
  sub = container.listen(jornadaImagesProvider(key), (_, next) {
    if (next.hasValue && !completer.isCompleted) {
      completer.complete(next.value!);
      sub.close();
    }
  }, fireImmediately: true);
  return completer.future;
}

void main() {
  // Lunes 28 de septiembre de 2026 (día normal, no festivo).
  final day = DateTime(2026, 9, 28);
  DateTime at(int h, int m, [DateTime? d]) {
    final base = d ?? day;
    return DateTime(base.year, base.month, base.day, h, m);
  }

  group('isImageOfJornada', () {
    const fecha = '2026-09-28';

    test('imagen de la jornada y del día: entra', () {
      expect(
        isImageOfJornada(_msg('a', at(8, 0)), fecha, Shift.morning),
        isTrue,
      );
    });

    test('otra jornada, otro día o sin imagen: no entra', () {
      expect(
        isImageOfJornada(_msg('a', at(12, 0)), fecha, Shift.morning),
        isFalse,
      );
      expect(
        isImageOfJornada(
          _msg('a', at(8, 0, DateTime(2026, 9, 29))),
          fecha,
          Shift.morning,
        ),
        isFalse,
      );
      expect(
        isImageOfJornada(
          _msg('a', at(8, 0), image: false),
          fecha,
          Shift.morning,
        ),
        isFalse,
      );
    });

    test('un hueco entre jornadas ("Fuera de jornada Mañana") no entra en '
        'ninguna jornada', () {
      final gap = _msg('a', at(10, 55));
      expect(gap.shift, shiftGapLabels[Shift.morning]);
      for (final shift in Shift.values) {
        expect(isImageOfJornada(gap, fecha, shift), isFalse, reason: '$shift');
      }
    });

    test('fuera de las jornadas (madrugada) no entra, ni pidiendo '
        'outOfShift', () {
      final night = _msg('a', at(23, 0));
      expect(isImageOfJornada(night, fecha, Shift.outOfShift), isFalse);
      expect(isImageOfJornada(night, fecha, Shift.night1), isFalse);
    });

    test('compareOldestFirst: por hora, luego shiftImageIndex, luego id', () {
      final list = [
        _msg('c', at(9, 0)),
        _msg('b', at(8, 0), index: 2),
        _msg('a', at(8, 0), index: 1),
        _msg('z', at(7, 0)),
      ]..sort(compareOldestFirst);
      expect(list.map((m) => m.id), ['z', 'a', 'b', 'c']);
    });
  });

  group('jornadaImagesProvider (día pasado)', () {
    final key = (chatJid: 'c1', date: day, shift: Shift.morning);

    ProviderContainer containerFor(_FakeRepo repo) {
      final container = ProviderContainer(
        overrides: [messagesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('solo imágenes de esa jornada y ese chat, de la primera a la '
        'última', () async {
      final repo = _FakeRepo([
        _msg('m2', at(9, 0)),
        _msg('m1', at(6, 0)),
        _msg('texto', at(7, 0), image: false),
        _msg('tarde', at(12, 0)),
        _msg('hueco', at(10, 55)),
        _msg('otro-chat', at(8, 0), chatJid: 'c2'),
        _msg('ayer', at(8, 0, DateTime(2026, 9, 27))),
      ]);
      final items = await _next(containerFor(repo), key);

      expect(items.map((i) => i.messageId), ['m1', 'm2']);
      expect(items.first.fechaJornada, '2026-09-28');
      // El rango pedido es el del día (DateFilterSpecificDay).
      expect(repo.pageCalls.first.from, day.millisecondsSinceEpoch);
      expect(
        repo.pageCalls.first.to,
        day.add(const Duration(days: 1)).millisecondsSinceEpoch,
      );
    });

    test('lee el día completo aunque ocupe varias páginas', () async {
      final repo = _FakeRepo([
        for (var i = 0; i < jornadaImagesPageSize + 3; i++)
          _msg('m$i', at(6, 0).add(Duration(seconds: i))),
      ]);
      final items = await _next(containerFor(repo), key);

      expect(items, hasLength(jornadaImagesPageSize + 3));
      expect(repo.pageCalls, hasLength(2));
      expect(
        repo.pageCalls.every((c) => c.limit == jornadaImagesPageSize),
        isTrue,
      );
      expect(items.first.messageId, 'm0');
    });

    test('un día pasado no escucha mensajes nuevos', () async {
      final repo = _FakeRepo([_msg('m1', at(6, 0))]);
      await _next(containerFor(repo), key);
      expect(repo.listenCalls, isEmpty);
    });

    test('día sin imágenes de la jornada: lista vacía', () async {
      final repo = _FakeRepo([_msg('tarde', at(12, 0))]);
      expect(await _next(containerFor(repo), key), isEmpty);
    });

    test(
      'si falla la lectura, el provider queda en error con el Failure',
      () async {
        final repo = _FakeRepo([])
          ..failure = const Failure.firestore(message: 'sin red');
        final container = containerFor(repo);
        final completer = Completer<Object>();
        container.listen(jornadaImagesProvider(key), (_, next) {
          if (next.hasError && !completer.isCompleted) {
            completer.complete(next.error!);
          }
        }, fireImmediately: true);

        expect(
          await completer.future,
          const Failure.firestore(message: 'sin red'),
        );
        // Sin reintento automático: cada reintento leería el día otra vez.
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(repo.pageCalls, hasLength(1));
      },
    );
  });

  group('jornadaImagesProvider (hoy, en vivo)', () {
    // La jornada de hoy a las 12:00 (Tarde 1, o Domingo/Festivo si hoy lo es).
    final today = DateUtils.dateOnly(DateTime.now());
    final noon = at(12, 0, today);
    final shift = shiftFromLabel(shiftViewerLabel(noon))!;
    final key = (chatJid: 'c1', date: today, shift: shift);

    test('las imágenes nuevas de la jornada se agregan al final; lo demás se '
        'ignora', () async {
      final repo = _FakeRepo([
        _msg('m1', noon),
        _msg('texto', noon.add(const Duration(minutes: 5)), image: false),
      ]);
      final container = ProviderContainer(
        overrides: [messagesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final values = <List<String>>[];
      container.listen(jornadaImagesProvider(key), (_, next) {
        if (next.hasValue) {
          values.add(next.value!.map((i) => i.messageId).toList());
        }
      }, fireImmediately: true);
      await pumpEventQueue();

      expect(values.last, ['m1']);
      // Escucha desde el último mensaje del día ya leído (el de texto).
      expect(repo.listenCalls, [
        noon.add(const Duration(minutes: 5)).millisecondsSinceEpoch,
      ]);

      repo.live
        ..add(_msg('m2', noon.add(const Duration(minutes: 10))))
        ..add(_msg('m1', noon)) // repetida
        ..add(
          _msg('texto2', noon.add(const Duration(minutes: 11)), image: false),
        )
        ..add(_msg('otro-dia', at(12, 0, today.add(const Duration(days: 1)))));
      await pumpEventQueue();

      expect(values.last, ['m1', 'm2']);
    });

    test('un error de la escucha no borra la lista', () async {
      final repo = _FakeRepo([_msg('m1', noon)]);
      final container = ProviderContainer(
        overrides: [messagesRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.listen(jornadaImagesProvider(key), (_, _) {});
      await pumpEventQueue();

      repo.live.addError(Exception('permission-denied'));
      await pumpEventQueue();
      repo.live.add(_msg('m2', noon.add(const Duration(minutes: 1))));
      await pumpEventQueue();

      final state = container.read(jornadaImagesProvider(key));
      expect(state.hasError, isFalse);
      expect(state.value!.map((i) => i.messageId), ['m1', 'm2']);
    });
  });
}
