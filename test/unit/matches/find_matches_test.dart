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
  messageEdited: false,
);

void main() {
  group('findMatches', () {
    test('"0123" coincide con "0123"', () {
      final entry = _entry('0123');

      expect(findMatches(['0123'], [entry]), [entry]);
    });

    test('"0123" NO coincide con "123": ceros a la izquierda importan', () {
      final entry = _entry('123');

      expect(findMatches(['0123'], [entry]), isEmpty);
    });

    test('"123" tampoco coincide con "0123" al revés', () {
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
}
