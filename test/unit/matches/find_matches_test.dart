import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/winning_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/find_matches.dart';

// Ajuste (comparación por lotería): los ganadores pasaron de lista de textos
// a pares (lotería, número). Los casos de la regla de 2, 3 y 4 cifras no
// cambian: usan una sola lotería por defecto (`_loteria`) en ganadores y
// registros, y la comparación por lotería tiene su grupo propio al final.
const _loteria = 'dorado_tarde';

List<WinningEntry> _w(List<String> numeros, {String loteria = _loteria}) => [
  for (final n in numeros) WinningEntry(loteria: loteria, numero: n),
];

MatchEntry _entry(
  String numero, {
  String messageId = 'm1',
  String chatJid = 'g1',
  String? loteria = _loteria,
}) => MatchEntry(
  numero: numero,
  loteria: loteria,
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

      expect(findMatches(_w(['0123']), [entry]), [entry]);
    });

    // Ajuste (regla de 3 y 4 cifras): antes "123" contra el ganador "0123"
    // no coincidía (igualdad exacta); ahora coincide como últimas 3.
    test('"123" coincide con el ganador "0123" como últimas 3', () {
      final entry = _entry('123');

      expect(findMatches(_w(['0123']), [entry]), [entry]);
    });

    test('"0123" NO coincide con el ganador "123": un boleto de 4 nunca '
        'coincide con un ganador de 3', () {
      final entry = _entry('0123');

      expect(findMatches(_w(['123']), [entry]), isEmpty);
    });

    test('los espacios alrededor se ignoran, en el ganador y en el '
        'registrado', () {
      final entry = _entry(' 4521 ');

      expect(findMatches(_w(['4521']), [entry]), [entry]);
      expect(findMatches(_w([' 4521']), [_entry('4521')]), [_entry('4521')]);
    });

    test('mayúsculas distintas no coinciden (sin normalizar)', () {
      final entry = _entry('abc1');

      expect(findMatches(_w(['ABC1']), [entry]), isEmpty);
    });

    test('la misma cifra en dos grupos da dos entradas', () {
      final norte = _entry('5566', messageId: 'm-norte', chatJid: 'norte@g.us');
      final centro = _entry(
        '5566',
        messageId: 'm-centro',
        chatJid: 'centro@g.us',
      );

      final result = findMatches(_w(['5566']), [norte, centro]);

      expect(result, containsAll([norte, centro]));
      expect(result, hasLength(2));
    });

    test('sin ganadores da lista vacía', () {
      expect(findMatches(_w([]), [_entry('1234')]), isEmpty);
    });

    test('con ganadores pero ningún registrado coincide: lista vacía', () {
      expect(
        findMatches(_w(['9999']), [_entry('1111'), _entry('2222')]),
        isEmpty,
      );
    });

    test('sin registrados da lista vacía aunque haya ganadores', () {
      expect(findMatches(_w(['1234']), []), isEmpty);
    });

    test(
      'no repite un registrado que coincide con dos ganadores distintos',
      () {
        final entry = _entry('7000');

        expect(findMatches(_w(['7000', '7000']), [entry]), [entry]);
      },
    );
  });

  group('findMatches: regla de 3 y 4 cifras', () {
    test('4 cifras igual al ganador completo coincide; distinto no', () {
      final igual = _entry('5241', messageId: 'a');
      final distinto = _entry('5242', messageId: 'b');

      expect(findMatches(_w(['5241']), [igual, distinto]), [igual]);
    });

    test('ganador "5241": "5241" gana, "241" gana, "524" pierde', () {
      final completo = _entry('5241', messageId: 'a');
      final ultimas3 = _entry('241', messageId: 'b');
      final primeras3 = _entry('524', messageId: 'c');

      expect(findMatches(_w(['5241']), [completo, ultimas3, primeras3]), [
        completo,
        ultimas3,
      ]);
    });

    test('"606" contra "606" y "4606" a la vez: una sola entrada', () {
      final entry = _entry('606');

      expect(findMatches(_w(['606', '4606']), [entry]), [entry]);
    });

    test('un boleto de 3 coincide con un ganador de 3', () {
      final entry = _entry('606');

      expect(findMatches(_w(['606']), [entry]), [entry]);
    });

    test('un boleto de 4 nunca coincide con un ganador de 3, aunque termine '
        'igual', () {
      expect(findMatches(_w(['606']), [_entry('0606')]), isEmpty);
      expect(findMatches(_w(['606']), [_entry('4606')]), isEmpty);
    });

    // Ajuste (regla de 2 cifras): antes también fijaba que "41" se ignoraba;
    // ahora un boleto de 2 cifras coincide con las últimas 2 de "5241", así
    // que sale de esta lista (se cubre en el grupo de 2 cifras).
    test('boletos de 1 y 5 cifras se ignoran', () {
      final entries = [
        _entry('1', messageId: 'a'),
        _entry('15241', messageId: 'c'),
      ];

      expect(
        findMatches(_w(['5241', '241', '41', '1', '15241']), entries),
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

      expect(findMatches(_w(['15241', '41', '']), entries), isEmpty);
    });

    test('ceros a la izquierda: "0123"="0123", "123" últimas 3 de "0123", '
        '"0123" no coincide con "123"', () {
      expect(findMatches(_w(['0123']), [_entry('0123')]), [_entry('0123')]);
      expect(findMatches(_w(['0123']), [_entry('123')]), [_entry('123')]);
      expect(findMatches(_w(['123']), [_entry('0123')]), isEmpty);
    });

    test('trim en ambos lados, también para las últimas 3', () {
      expect(findMatches(_w([' 5241 ']), [_entry(' 241 ')]), [_entry(' 241 ')]);
      expect(findMatches(_w([' 606']), [_entry('606 ')]), [_entry('606 ')]);
      expect(findMatches(_w(['5241']), [_entry('  5241')]), [_entry('  5241')]);
    });

    test(
      'devuelve la entrada tal cual (sin trim) y no modifica las listas',
      () {
        final winners = _w([' 5241 ', '606']);
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

      expect(findMatches(_w(['606', '4606', '1606']), [a, b]), [a, b]);
    });
  });

  group('findMatches: boletos de 2 cifras', () {
    test('ganador "5241": "5241", "241" y "41" coinciden; "524", "52" y '
        '"24" no', () {
      final completo = _entry('5241', messageId: 'a');
      final ultimas3 = _entry('241', messageId: 'b');
      final ultimas2 = _entry('41', messageId: 'c');
      final primeras3 = _entry('524', messageId: 'd');
      final primeras2 = _entry('52', messageId: 'e');
      final medio = _entry('24', messageId: 'f');

      expect(
        findMatches(_w(['5241']), [
          completo,
          ultimas3,
          ultimas2,
          primeras3,
          primeras2,
          medio,
        ]),
        [completo, ultimas3, ultimas2],
      );
    });

    test('ganador "606": "606" y "06" coinciden; "60" y "0606" no', () {
      final completo = _entry('606', messageId: 'a');
      final ultimas2 = _entry('06', messageId: 'b');
      final primeras2 = _entry('60', messageId: 'c');
      final cuatro = _entry('0606', messageId: 'd');

      expect(
        findMatches(_w(['606']), [completo, ultimas2, primeras2, cuatro]),
        [completo, ultimas2],
      );
    });

    test('un ganador de 3 cifras sigue sin coincidir con un boleto de 4', () {
      expect(findMatches(_w(['241']), [_entry('5241')]), isEmpty);
      expect(findMatches(_w(['606']), [_entry('4606')]), isEmpty);
    });

    test('"41" contra "5241" y "0341": una sola entrada', () {
      final entry = _entry('41');

      expect(findMatches(_w(['5241', '0341']), [entry]), [entry]);
    });

    test('ceros a la izquierda: "07" coincide con "4607" y no con "0770"', () {
      expect(findMatches(_w(['4607']), [_entry('07')]), [_entry('07')]);
      expect(findMatches(_w(['0770']), [_entry('07')]), isEmpty);
    });

    test('trim en ambos lados, también para las últimas 2', () {
      expect(findMatches(_w([' 5241 ']), [_entry(' 41 ')]), [_entry(' 41 ')]);
      expect(findMatches(_w(['606 ']), [_entry(' 06')]), [_entry(' 06')]);
    });

    test('boletos de 1 y de 5 cifras se ignoran', () {
      expect(findMatches(_w(['5241']), [_entry('1')]), isEmpty);
      expect(findMatches(_w(['5241']), [_entry('15241')]), isEmpty);
    });

    test('ganadores de 2 y de 5 cifras se ignoran', () {
      final entries = [
        _entry('41', messageId: 'a'),
        _entry('241', messageId: 'b'),
        _entry('5241', messageId: 'c'),
      ];

      expect(findMatches(_w(['41', '15241']), entries), isEmpty);
    });

    test('no modifica las listas', () {
      final winners = _w([' 5241 ', '606']);
      final entries = [
        _entry(' 41 ', messageId: 'a'),
        _entry('06', messageId: 'b'),
        _entry('60', messageId: 'c'),
      ];
      final winnersBefore = List.of(winners);
      final entriesBefore = List.of(entries);

      final result = findMatches(winners, entries);

      expect(result, [entries[0], entries[1]]);
      expect(winners, winnersBefore);
      expect(entries, entriesBefore);
    });
  });

  group('findMatches: por lotería', () {
    test('el mismo número en dos loterías coincide solo con la suya', () {
      final tarde = _entry('1288', messageId: 'a', loteria: 'dorado_tarde');
      final noche = _entry('1288', messageId: 'b', loteria: 'dorado_noche');
      final winners = _w(['1288'], loteria: 'dorado_tarde');

      expect(findMatches(winners, [tarde, noche]), [tarde]);
      expect(
        findMatches(_w(['1288'], loteria: 'dorado_noche'), [tarde, noche]),
        [noche],
      );
    });

    test(
      'dos ganadores iguales de loterías distintas: cada boleto con la suya, '
      'una sola vez',
      () {
        final tarde = _entry('1288', messageId: 'a', loteria: 'dorado_tarde');
        final noche = _entry('1288', messageId: 'b', loteria: 'dorado_noche');
        final winners = [
          const WinningEntry(loteria: 'dorado_tarde', numero: '1288'),
          const WinningEntry(loteria: 'dorado_noche', numero: '1288'),
        ];

        expect(findMatches(winners, [tarde, noche]), [tarde, noche]);
      },
    );

    test('un boleto con lotería nula, vacía o fuera de la lista no coincide '
        'con nada, aunque haya un ganador con ese texto', () {
      final nula = _entry('1288', messageId: 'a', loteria: null);
      final vacia = _entry('1288', messageId: 'b', loteria: '');
      final fuera = _entry('1288', messageId: 'c', loteria: 'baloto');
      final espacios = _entry('1288', messageId: 'd', loteria: ' dorado_tarde');
      final winners = [
        const WinningEntry(loteria: 'dorado_tarde', numero: '1288'),
        const WinningEntry(loteria: '', numero: '1288'),
        const WinningEntry(loteria: 'baloto', numero: '1288'),
      ];

      expect(findMatches(winners, [nula, vacia, fuera, espacios]), isEmpty);
    });

    test(
      'un ganador de una lotería fuera de la lista no coincide con nada',
      () {
        final entry = _entry('1288', loteria: 'medellin');

        expect(findMatches(_w(['1288'], loteria: 'baloto'), [entry]), isEmpty);
      },
    );

    test('la regla de 2, 3 y 4 cifras vale dentro de cada lotería', () {
      final propios = [
        _entry('5241', messageId: 'a', loteria: 'medellin'),
        _entry('241', messageId: 'b', loteria: 'medellin'),
        _entry('41', messageId: 'c', loteria: 'medellin'),
      ];
      final ajenos = [
        _entry('5241', messageId: 'd', loteria: 'valle'),
        _entry('241', messageId: 'e', loteria: 'valle'),
        _entry('41', messageId: 'f', loteria: 'valle'),
      ];
      final winners = _w(['5241'], loteria: 'medellin');

      expect(findMatches(winners, [...propios, ...ajenos]), propios);
    });

    test('un registro sale una sola vez aunque coincida con varios ganadores '
        'de su lotería', () {
      final entry = _entry('606');
      final winners = _w(['606', '4606']);

      expect(findMatches(winners, [entry]), [entry]);
    });
  });

  group('winningNumbersFor', () {
    test('un registro de 3 cifras trae el ganador completo de 4', () {
      expect(winningNumbersFor(_w(['4606']), _entry('606')), ['4606']);
    });

    test('un registro de 2 cifras trae el ganador de 4 o de 3', () {
      expect(winningNumbersFor(_w(['5241']), _entry('41')), ['5241']);
      expect(winningNumbersFor(_w(['606']), _entry('06')), ['606']);
    });

    test('un registro igual al ganador lo trae tal cual', () {
      expect(winningNumbersFor(_w(['0123']), _entry('0123')), ['0123']);
      expect(winningNumbersFor(_w(['606']), _entry('606')), ['606']);
    });

    test('si coincide con varios, primero el de más cifras y sin repetir', () {
      expect(winningNumbersFor(_w(['606', '4606', '606']), _entry('606')), [
        '4606',
        '606',
      ]);
    });

    test('un registro de 4 nunca trae un ganador de 3', () {
      expect(winningNumbersFor(_w(['606']), _entry('0606')), isEmpty);
    });

    test('solo ganadores de la misma lotería', () {
      expect(
        winningNumbersFor(_w(['4606'], loteria: 'medellin'), _entry('606')),
        isEmpty,
      );
    });

    test('lotería nula o fuera de la lista no trae nada', () {
      expect(
        winningNumbersFor(_w(['4606']), _entry('606', loteria: null)),
        isEmpty,
      );
      expect(
        winningNumbersFor(_w(['4606']), _entry('606', loteria: 'inventada')),
        isEmpty,
      );
    });

    test('coincide exactamente cuando findMatches lo dice', () {
      final winners = _w(['4606', '9014']);
      for (final numero in ['606', '06', '4606', '014', '9014', '0606', '5']) {
        final entry = _entry(numero);
        expect(
          winningNumbersFor(winners, entry).isNotEmpty,
          findMatches(winners, [entry]).isNotEmpty,
          reason: numero,
        );
      }
    });
  });
}
