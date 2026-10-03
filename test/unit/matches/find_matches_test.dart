import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/find_matches.dart';

MatchEntry _entry(
  String numero, {
  String messageId = 'm1',
  String chatJid = 'g1',
}) => MatchEntry(
  numero: numero,
  messageId: messageId,
  chatJid: chatJid,
  groupName: 'Grupo',
  senderName: 'Ana',
  localTime: '08:00',
  storagePath: 'demo/x.jpg',
  shift: 'Jornada Mañana (06:00 – 10:54)',
  fechaJornada: '2026-09-28',
);

void main() {
  group('findMatches', () {
    test('"0123" coincide con "0123"', () {
      final entry = _entry('0123');

      expect(findMatches(['0123'], [entry]), [entry]);
    });

    // Ajuste (regla de 3 y 4 cifras): antes "123" contra el ganador "0123"
    // no coincidía (igualdad exacta); ahora coincide como últimas 3.
    test('"123" coincide con el ganador "0123" como últimas 3', () {
      final entry = _entry('123');

      expect(findMatches(['0123'], [entry]), [entry]);
    });

    test('"0123" NO coincide con el ganador "123": un boleto de 4 nunca '
        'coincide con un ganador de 3', () {
      final entry = _entry('0123');

      expect(findMatches(['123'], [entry]), isEmpty);
    });

    test('los espacios alrededor se ignoran, en el ganador y en el '
        'registrado', () {
      final entry = _entry(' 4521 ');

      expect(findMatches(['4521'], [entry]), [entry]);
      expect(findMatches([' 4521'], [_entry('4521')]), [_entry('4521')]);
    });

    test('mayúsculas distintas no coinciden (sin normalizar)', () {
      final entry = _entry('abc1');

      expect(findMatches(['ABC1'], [entry]), isEmpty);
    });

    test('la misma cifra en dos grupos da dos entradas', () {
      final norte = _entry('5566', messageId: 'm-norte', chatJid: 'norte@g.us');
      final centro = _entry(
        '5566',
        messageId: 'm-centro',
        chatJid: 'centro@g.us',
      );

      final result = findMatches(['5566'], [norte, centro]);

      expect(result, containsAll([norte, centro]));
      expect(result, hasLength(2));
    });

    test('sin ganadores da lista vacía', () {
      expect(findMatches([], [_entry('1234')]), isEmpty);
    });

    test('con ganadores pero ningún registrado coincide: lista vacía', () {
      expect(findMatches(['9999'], [_entry('1111'), _entry('2222')]), isEmpty);
    });

    test('sin registrados da lista vacía aunque haya ganadores', () {
      expect(findMatches(['1234'], []), isEmpty);
    });

    test(
      'no repite un registrado que coincide con dos ganadores distintos',
      () {
        final entry = _entry('7000');

        expect(findMatches(['7000', '7000'], [entry]), [entry]);
      },
    );
  });

  group('findMatches: regla de 3 y 4 cifras', () {
    test('4 cifras igual al ganador completo coincide; distinto no', () {
      final igual = _entry('5241', messageId: 'a');
      final distinto = _entry('5242', messageId: 'b');

      expect(findMatches(['5241'], [igual, distinto]), [igual]);
    });

    test('ganador "5241": "5241" gana, "241" gana, "524" pierde', () {
      final completo = _entry('5241', messageId: 'a');
      final ultimas3 = _entry('241', messageId: 'b');
      final primeras3 = _entry('524', messageId: 'c');

      expect(findMatches(['5241'], [completo, ultimas3, primeras3]), [
        completo,
        ultimas3,
      ]);
    });

    test('"606" contra "606" y "4606" a la vez: una sola entrada', () {
      final entry = _entry('606');

      expect(findMatches(['606', '4606'], [entry]), [entry]);
    });

    test('un boleto de 3 coincide con un ganador de 3', () {
      final entry = _entry('606');

      expect(findMatches(['606'], [entry]), [entry]);
    });

    test('un boleto de 4 nunca coincide con un ganador de 3, aunque termine '
        'igual', () {
      expect(findMatches(['606'], [_entry('0606')]), isEmpty);
      expect(findMatches(['606'], [_entry('4606')]), isEmpty);
    });

    test('boletos de 1, 2 y 5 cifras se ignoran', () {
      final entries = [
        _entry('1', messageId: 'a'),
        _entry('41', messageId: 'b'),
        _entry('15241', messageId: 'c'),
      ];

      expect(
        findMatches(['5241', '241', '41', '1', '15241'], entries),
        isEmpty,
      );
    });

    test('un ganador de longitud distinta de 3 o 4 se ignora', () {
      // "15241" (5) no aporta ni completo ni últimas 3; "41" (2) tampoco.
      final entries = [
        _entry('5241', messageId: 'a'),
        _entry('241', messageId: 'b'),
        _entry('41', messageId: 'c'),
      ];

      expect(findMatches(['15241', '41', ''], entries), isEmpty);
    });

    test('ceros a la izquierda: "0123"="0123", "123" últimas 3 de "0123", '
        '"0123" no coincide con "123"', () {
      expect(findMatches(['0123'], [_entry('0123')]), [_entry('0123')]);
      expect(findMatches(['0123'], [_entry('123')]), [_entry('123')]);
      expect(findMatches(['123'], [_entry('0123')]), isEmpty);
    });

    test('trim en ambos lados, también para las últimas 3', () {
      expect(findMatches([' 5241 '], [_entry(' 241 ')]), [_entry(' 241 ')]);
      expect(findMatches([' 606'], [_entry('606 ')]), [_entry('606 ')]);
      expect(findMatches(['5241'], [_entry('  5241')]), [_entry('  5241')]);
    });

    test(
      'devuelve la entrada tal cual (sin trim) y no modifica las listas',
      () {
        final winners = [' 5241 ', '606'];
        final entries = [
          _entry(' 241 ', messageId: 'a'),
          _entry('0606', messageId: 'b'),
        ];
        final winnersBefore = List.of(winners);
        final entriesBefore = List.of(entries);

        final result = findMatches(winners, entries);

        expect(result, [entries[0]]);
        expect(result.single.numero, ' 241 ');
        expect(winners, winnersBefore);
        expect(entries, entriesBefore);
      },
    );

    test('dos registros con el mismo número: cada uno sale una vez', () {
      final a = _entry('606', messageId: 'a');
      final b = _entry('606', messageId: 'b');

      expect(findMatches(['606', '4606', '1606'], [a, b]), [a, b]);
    });
  });
}
