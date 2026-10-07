import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/lotteries/lotteries.dart';

void main() {
  group('lista cerrada de loterías', () {
    test('son exactamente 43', () {
      expect(lotteries, hasLength(43));
    });

    test('sin identificadores repetidos', () {
      final ids = lotteries.map((l) => l.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('cada una tiene nombre para mostrar, y los nombres no se repiten', () {
      for (final l in lotteries) {
        expect(l.name.trim(), isNotEmpty, reason: l.id);
        expect(l.name, isNot(contains('_')), reason: l.id);
      }
      final names = lotteries.map((l) => l.name).toList();
      expect(names.toSet(), hasLength(names.length));
    });

    test('los identificadores son claves normalizadas (minúsculas, sin tildes '
        'ni espacios), como las de lotteryKey de la función puente', () {
      for (final l in lotteries) {
        expect(RegExp(r'^[a-z0-9_]+$').hasMatch(l.id), isTrue, reason: l.id);
      }
    });

    test('es la lista decidida: identificador y nombre, en orden', () {
      expect(
        [for (final l in lotteries) '${l.id}=${l.name}'],
        [
          'medellin=Medellín',
          'santander=Santander',
          'risaralda=Risaralda',
          'dorado_manana=Dorado mañana',
          'dorado_tarde=Dorado tarde',
          'dorado_noche=Dorado noche',
          'culona=Culona',
          'culona_noche=Culona noche',
          'astro_sol=Astro sol',
          'astro_luna=Astro luna',
          'pijao_de_oro=Pijao de oro',
          'paisita_dia=Paisita día',
          'paisita_noche=Paisita noche',
          'chontico_dia=Chontico día',
          'chontico_noche=Chontico noche',
          'cafeterito_tarde=Cafeterito tarde',
          'cafeterito_noche=Cafeterito noche',
          'sinuano_dia=Sinuano día',
          'sinuano_noche=Sinuano noche',
          'cash_three_dia=Cash three día',
          'cash_three_noche=Cash three noche',
          'play_four_dia=Play four día',
          'play_four_noche=Play four noche',
          'saman_dia=Saman día',
          'caribena_dia=Caribeña día',
          'caribena_noche=Caribeña noche',
          'motilon_tarde=Motilón tarde',
          'motilon_noche=Motilón noche',
          'fantastica_dia=Fantástica día',
          'fantastica_noche=Fantástica noche',
          'antioquenita_dia=Antioqueñita día',
          'antioquenita_tarde=Antioqueñita tarde',
          'meta=Meta',
          'valle=Valle',
          'manizales=Manizales',
          'bogota=Bogotá',
          'huila=Huila',
          'cruz_roja=Cruz Roja',
          'cundinamarca=Cundinamarca',
          'cauca=Cauca',
          'tolima=Tolima',
          'boyaca=Boyacá',
          'quindio=Quindío',
        ],
      );
    });
  });

  group('loteriaDisplayName', () {
    test('devuelve el nombre de cada identificador de la lista', () {
      for (final l in lotteries) {
        expect(loteriaDisplayName(l.id), l.name, reason: l.id);
      }
      expect(loteriaDisplayName('dorado_manana'), 'Dorado mañana');
      expect(loteriaDisplayName('bogota'), 'Bogotá');
    });

    test('si no está en la lista devuelve el mismo texto recibido', () {
      for (final texto in [
        'Baloto',
        'Lotería de Medellín',
        'Medellín', // el nombre no es un identificador
        'MEDELLIN',
        ' medellin',
        '',
      ]) {
        expect(loteriaDisplayName(texto), texto, reason: '"$texto"');
      }
    });
  });

  group('isKnownLoteria', () {
    test('solo los identificadores exactos de la lista', () {
      expect(isKnownLoteria('medellin'), isTrue);
      expect(isKnownLoteria('quindio'), isTrue);
      expect(isKnownLoteria(null), isFalse);
      expect(isKnownLoteria(''), isFalse);
      expect(isKnownLoteria('Medellín'), isFalse);
      expect(isKnownLoteria('MEDELLIN'), isFalse);
      expect(isKnownLoteria(' medellin'), isFalse);
      expect(isKnownLoteria('baloto'), isFalse);
    });
  });
}
