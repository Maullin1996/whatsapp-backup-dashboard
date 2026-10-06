import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/message_context_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/revisor_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/find_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';

/// [MatchesRepository] con los datos reales: los números ganadores del día,
/// los registros del Revisor de ese día (todos los grupos y jornadas), el
/// mensaje de cada coincidencia y el nombre de su grupo. Nombre PROVISIONAL.
///
/// Los ganadores de una fecha se comparan contra TODOS los números del
/// Revisor de esa fecha (`findMatches`, por lotería y número); la jornada solo
/// agrupa lo que se muestra. Sin caché ni reintentos.
class FirestoreMatchesRepository implements MatchesRepository {
  final WinningNumbersDatasource _winners;
  final RevisorRecordsDatasource _records;
  final MessageContextDatasource _messages;
  final GroupNameDatasource _groupNames;

  const FirestoreMatchesRepository({
    required WinningNumbersDatasource winners,
    required RevisorRecordsDatasource records,
    required MessageContextDatasource messages,
    required GroupNameDatasource groupNames,
  }) : _winners = winners,
       _records = records,
       _messages = messages,
       _groupNames = groupNames;

  /// - Jornadas: las del día (domingo o festivo: solo `holiday`; si no,
  ///   mañana, tarde 1, tarde 2 y noche 1) más cualquier otra con registros
  ///   del Revisor
  ///   (p. ej. `night2`), por el orden del enum. Todas con los MISMOS
  ///   ganadores del día.
  /// - Sin ganadores: esas jornadas vacías, sin leer registros.
  /// - Con ganadores: solo las coincidencias leen su mensaje (una vez por
  ///   messageId) y su grupo (una vez por chatJid; sin documento, el
  ///   chatJid). Orden: grupo, chatJid, messageId y número.
  /// - Cualquier lectura fallida → `Left`. Nunca lanza.
  @override
  Future<Either<Failure, DayMatches>> getMatches(DateTime date) async {
    try {
      return await _build(date);
    } catch (_) {
      return const Left(
        Failure.unknown(
          message: 'Error inesperado al armar las coincidencias.',
        ),
      );
    }
  }

  Future<Either<Failure, DayMatches>> _build(DateTime date) async {
    // Mismo día y mismas etiquetas que el mock y el Resumen real.
    final day = DateTime(date.year, date.month, date.day);
    final fechaJornada = fechaJornadaDe(day.millisecondsSinceEpoch);
    // night2 no está en la tabla: si aparece, su etiqueta vieja.
    String label(Shift shift) => shiftNames[shift] ?? legacyShiftNames[shift]!;

    final winnersResult = await _winners.fetchByFecha(fechaJornada);
    final winners = winnersResult.fold((_) => null, (list) => list);
    if (winners == null) return Left(_failureOf(winnersResult));

    final baseShifts = _shiftsOfDay(day);
    if (winners.isEmpty) {
      return Right(
        DayMatches(
          fechaJornada: fechaJornada,
          jornadas: [
            for (final shift in baseShifts)
              JornadaMatches(
                shift: label(shift),
                winningNumbers: const [],
                matches: const [],
              ),
          ],
        ),
      );
    }

    final recordsResult = await _records.fetchByFechaJornada(fechaJornada);
    final records = recordsResult.fold((_) => null, (list) => list);
    if (records == null) return Left(_failureOf(recordsResult));

    // Un MatchEntry provisional por registro y número (con la lotería de su
    // comprobante), con el contexto vacío;
    // la jornada de cada uno se recuerda aparte (la entidad lleva la etiqueta).
    final shiftOf = <MatchEntry, Shift>{};
    final provisional = <MatchEntry>[];
    for (final r in records) {
      for (final recorded in r.numeros) {
        final entry = MatchEntry(
          numero: recorded.numero,
          loteria: recorded.loteria,
          messageId: r.messageId,
          chatJid: r.chatJid,
          groupName: '',
          senderName: '',
          localTime: '',
          storagePath: r.storagePath,
          shift: label(r.shift),
          fechaJornada: r.fechaJornada,
        );
        provisional.add(entry);
        shiftOf[entry] = r.shift;
      }
    }
    final matched = findMatches(winners, provisional);

    final messages = <String, MessageContext>{};
    for (final messageId in {for (final m in matched) m.messageId}) {
      final result = await _messages.fetchById(messageId);
      final context = result.fold((_) => null, (c) => c);
      if (context == null) return Left(_failureOf(result));
      messages[messageId] = context;
    }

    final groupNames = <String, String>{};
    for (final chatJid in {for (final m in matched) m.chatJid}) {
      final result = await _groupNames.fetchGroupName(chatJid);
      final failure = result.fold((f) => f, (_) => null);
      if (failure != null) return Left(failure);
      groupNames[chatJid] = result.getOrElse(() => null) ?? chatJid;
    }

    final complete = [
      for (final m in matched)
        (
          shift: shiftOf[m]!,
          entry: m.copyWith(
            senderName: messages[m.messageId]!.senderName,
            localTime: messages[m.messageId]!.localTime,
            groupName: groupNames[m.chatJid]!,
          ),
        ),
    ]..sort((a, b) => _compare(a.entry, b.entry));

    final shifts = {...baseShifts, for (final r in records) r.shift}.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return Right(
      DayMatches(
        fechaJornada: fechaJornada,
        jornadas: [
          for (final shift in shifts)
            JornadaMatches(
              shift: label(shift),
              winningNumbers: winners,
              matches: [
                for (final c in complete)
                  if (c.shift == shift) c.entry,
              ],
            ),
        ],
      ),
    );
  }

  /// Jornadas de [day] sin contar registros: domingo o festivo, solo
  /// `holiday` ([isHolidayOrSunday], igual que el resto de la app); el resto
  /// de días, las cuatro de siempre.
  static List<Shift> _shiftsOfDay(DateTime day) => isHolidayOrSunday(day)
      ? const [Shift.holiday]
      : const [Shift.morning, Shift.afternoon1, Shift.afternoon2, Shift.night1];

  static int _compare(MatchEntry a, MatchEntry b) {
    for (final (x, y) in [
      (a.groupName.toLowerCase(), b.groupName.toLowerCase()),
      (a.chatJid, b.chatJid),
      (a.messageId, b.messageId),
      (a.numero, b.numero),
    ]) {
      final byField = x.compareTo(y);
      if (byField != 0) return byField;
    }
    return 0;
  }

  static Failure _failureOf<T>(Either<Failure, T> result) =>
      result.fold((f) => f, (_) => throw StateError('se esperaba Left'));
}
