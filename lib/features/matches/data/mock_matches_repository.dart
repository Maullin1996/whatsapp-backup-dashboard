import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/find_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';

/// Qué muestra cada jornada del día generado (una por jornada; el día se
/// arma repartiendo estos cuatro escenarios entre las cuatro jornadas de
/// [MockMatchesRepository._shifts]), salvo un día "sin ganadores" (todas las
/// jornadas con lista de ganadores vacía).
enum _JornadaScenario {
  /// Un ganador con una coincidencia.
  unaCoincidencia,

  /// El mismo número ganador coincide con registros de dos grupos distintos.
  mismaCifraDosGrupos,

  /// Hay números ganadores, pero ninguno coincide con lo registrado.
  sinCoincidencias,

  /// Ceros a la izquierda: "0123" (ganador) coincide, "123" (registrado
  /// aparte) NO, porque son strings distintos.
  cerosIzquierda,
}

/// TEMPORAL — reemplazar por un `MatchesRepository` real cuando exista la
/// Cloud Function puente de números ganadores (paso 7, ver
/// `image-review-firebase-integration`). Los campos que arma este mock
/// (`chatJid`, `groupName`, `senderName`, `storagePath`, números ganadores)
/// son SUPUESTOS para poder mostrar el diseño — no son contrato: el formato
/// real de la fuente de números ganadores queda diferido a ese paso.
///
/// Genera datos inventados pero DETERMINISTAS por fecha: la fecha es la
/// semilla, así que el mismo día devuelve siempre lo mismo. Las
/// coincidencias nunca se hardcodean: se arman generando ganadores y
/// registros inventados y cruzándolos con `findMatches`, igual que hará la
/// implementación real. No modela las jornadas distintas de los domingos
/// (mismo hueco documentado que `MockSummaryRepository`, ver
/// `image-review-domain`).
class MockMatchesRepository implements MatchesRepository {
  /// [latency] simula la espera de una lectura real; los tests usan
  /// `Duration.zero`.
  const MockMatchesRepository({
    this.latency = const Duration(milliseconds: 400),
  });

  final Duration latency;

  static const _groups = [
    (chatJid: 'demo-grupo-norte@g.us', name: 'Grupo Norte (demo)'),
    (chatJid: 'demo-grupo-centro@g.us', name: 'Grupo Centro (demo)'),
    (chatJid: 'demo-grupo-sur@g.us', name: 'Grupo Sur (demo)'),
  ];

  static const _senderNames = ['Ana', 'Luis', 'Marta', 'Pedro'];

  static const _shifts = [
    Shift.morning,
    Shift.afternoon1,
    Shift.afternoon2,
    Shift.night1,
  ];

  @override
  Future<Either<Failure, DayMatches>> getMatches(DateTime date) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return Right(_generate(date));
  }

  DayMatches _generate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final random = Random(day.year * 10000 + day.month * 100 + day.day);
    final fechaJornada = fechaJornadaDe(day.millisecondsSinceEpoch);

    // ~1 de cada 4 días no tiene ningún número ganador ese día.
    final sinGanadores = random.nextInt(4) == 0;
    final scenarioOrder = sinGanadores
        ? null
        : ([..._JornadaScenario.values]..shuffle(random));

    final jornadas = [
      for (var i = 0; i < _shifts.length; i++)
        _buildJornada(
          shift: _shifts[i],
          fechaJornada: fechaJornada,
          scenario: sinGanadores ? null : scenarioOrder![i],
          random: random,
        ),
    ];

    return DayMatches(fechaJornada: fechaJornada, jornadas: jornadas);
  }

  JornadaMatches _buildJornada({
    required Shift shift,
    required String fechaJornada,
    required _JornadaScenario? scenario,
    required Random random,
  }) {
    final shiftLabel = shiftNames[shift]!;
    if (scenario == null) {
      return JornadaMatches(
        shift: shiftLabel,
        winningNumbers: const [],
        matches: const [],
      );
    }

    var nextIndex = 0;
    MatchEntry entry(String numero, int groupIndex) {
      final group = _groups[groupIndex];
      final id = 'demo-msg-${fechaJornada}_${shift.name}_${nextIndex++}';
      return MatchEntry(
        numero: numero,
        messageId: id,
        chatJid: group.chatJid,
        groupName: group.name,
        senderName: _senderNames[random.nextInt(_senderNames.length)],
        localTime:
            '${(6 + random.nextInt(16)).toString().padLeft(2, '0')}:'
            '${random.nextInt(60).toString().padLeft(2, '0')}',
        storagePath: 'demo/$fechaJornada/${shift.name}/$id.jpg',
        shift: shiftLabel,
        fechaJornada: fechaJornada,
        messageEdited: random.nextInt(5) == 0,
      );
    }

    final List<String> winningNumbers;
    final registered = <MatchEntry>[];
    switch (scenario) {
      case _JornadaScenario.unaCoincidencia:
        registered.add(entry('4521', 0));
        registered.add(entry('7788', 1));
        winningNumbers = const ['4521'];
      case _JornadaScenario.mismaCifraDosGrupos:
        registered.add(entry('5566', 0));
        registered.add(entry('5566', 1));
        registered.add(entry('2231', 2));
        winningNumbers = const ['5566'];
      case _JornadaScenario.sinCoincidencias:
        registered.add(entry('1180', 0));
        registered.add(entry('3342', 1));
        winningNumbers = const ['9999'];
      case _JornadaScenario.cerosIzquierda:
        registered.add(entry('0123', 0));
        registered.add(entry('123', 1));
        winningNumbers = const ['0123'];
    }

    return JornadaMatches(
      shift: shiftLabel,
      winningNumbers: winningNumbers,
      matches: findMatches(winningNumbers, registered),
    );
  }
}
