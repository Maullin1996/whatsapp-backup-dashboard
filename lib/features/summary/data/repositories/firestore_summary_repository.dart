import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/summary_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';

/// [SummaryRepository] con los datos reales: los registros subidos de un día
/// (todos los grupos), los contadores del bot de ese día y el nombre de cada
/// grupo. Nombre PROVISIONAL.
///
/// TODAVÍA NO CONECTADO: `summaryRepositoryProvider` sigue en el mock.
class FirestoreSummaryRepository implements SummaryRepository {
  final SummaryRecordsDatasource _records;
  final ShiftImageCountsDatasource _counts;
  final GroupNameDatasource _groupNames;

  const FirestoreSummaryRepository({
    required SummaryRecordsDatasource records,
    required ShiftImageCountsDatasource counts,
    required GroupNameDatasource groupNames,
  }) : _records = records,
       _counts = counts,
       _groupNames = groupNames;

  /// - Un resumen por cada (grupo, jornada) que tenga contador o registros
  ///   ese día; cada jornada por separado, nunca combinadas por día.
  /// - Orden como el mock: por grupo (nombre, luego chatJid) y, dentro del
  ///   grupo, por jornada.
  /// - `Left` si fallan los registros o los contadores; si falla el nombre
  ///   de un grupo, se usa su chatJid. Nunca lanza.
  @override
  Future<Either<Failure, List<JornadaSummary>>> getJornadaSummaries(
    DateTime fecha,
  ) async {
    try {
      return await _build(fecha);
    } catch (_) {
      return const Left(
        Failure.unknown(message: 'Error inesperado al armar el resumen.'),
      );
    }
  }

  Future<Either<Failure, List<JornadaSummary>>> _build(DateTime fecha) async {
    // Mismo día y mismas etiquetas que el mock.
    final day = DateTime(fecha.year, fecha.month, fecha.day);
    final fechaJornada = fechaJornadaDe(day.millisecondsSinceEpoch);
    final names = shiftNamesAt(day.millisecondsSinceEpoch);

    final recordsFuture = _records.fetchByFechaJornada(fechaJornada);
    final countsFuture = _counts.fetchByShiftDate(fechaJornada);
    final recordsResult = await recordsFuture;
    final countsResult = await countsFuture;

    for (final failure in [
      recordsResult.fold((f) => f, (_) => null),
      countsResult.fold((f) => f, (_) => null),
    ]) {
      if (failure != null) return Left(failure);
    }
    final records = recordsResult.getOrElse(() => const []);
    final counts = countsResult.getOrElse(() => const []);

    // Universo: (grupo, jornada) con contador o con registros.
    final recordsByKey = <(String, Shift), List<SummaryRecord>>{};
    for (final r in records) {
      recordsByKey.putIfAbsent((r.chatJid, r.shift), () => []).add(r);
    }
    final lastIndexByKey = {
      for (final c in counts) (c.chatJid, c.shift): c.lastIndex,
    };
    final keys = {...recordsByKey.keys, ...lastIndexByKey.keys};
    if (keys.isEmpty) return const Right([]);

    final groupNames = await _fetchGroupNames({for (final k in keys) k.$1});

    final sortedKeys = keys.toList()
      ..sort((a, b) {
        final nameA = groupNames[a.$1]!.toLowerCase();
        final nameB = groupNames[b.$1]!.toLowerCase();
        final byName = nameA.compareTo(nameB);
        if (byName != 0) return byName;
        final byJid = a.$1.compareTo(b.$1);
        if (byJid != 0) return byJid;
        return a.$2.index.compareTo(b.$2.index);
      });

    return Right([
      for (final key in sortedKeys)
        JornadaSummary(
          chatJid: key.$1,
          groupName: groupNames[key.$1]!,
          fechaJornada: fechaJornada,
          // night2 no existe en la tabla nueva: si aparece, su etiqueta vieja.
          shift: names[key.$2] ?? shiftNames[key.$2]!,
          revisor: _roleSummary(recordsByKey[key], ReviewRole.revisor),
          sumador: _roleSummary(recordsByKey[key], ReviewRole.sumador),
          imagenesEnJornada: lastIndexByKey[key] ?? 0,
        ),
    ]);
  }

  /// Nombre de cada grupo; el chatJid si el documento no existe o la lectura
  /// falla (el Resumen sigue igual).
  Future<Map<String, String>> _fetchGroupNames(Set<String> chatJids) async {
    final entries = await Future.wait([
      for (final chatJid in chatJids)
        _groupNames
            .fetchGroupName(chatJid)
            .then(
              (result) => MapEntry(
                chatJid,
                result.fold((_) => chatJid, (name) => name ?? chatJid),
              ),
            )
            .catchError((Object _) => MapEntry(chatJid, chatJid)),
    ]);
    return Map.fromEntries(entries);
  }

  /// Lo que registró [rol] en la jornada: cantidad de registros (imágenes),
  /// cantidad de comprobantes (tickets) y suma de sus totales.
  static RoleSummary _roleSummary(
    List<SummaryRecord>? jornadaRecords,
    ReviewRole rol,
  ) {
    final mine = [
      for (final r in jornadaRecords ?? const <SummaryRecord>[])
        if (r.rol == rol) r,
    ];
    if (mine.isEmpty) return RoleSummary.sinRegistrar;
    return RoleSummary(
      registrado: true,
      cantidadImagenes: mine.length,
      cantidadTickets: mine.fold(0, (n, r) => n + r.totales.length),
      totalSuma: mine.fold(0, (sum, r) => sum + r.totales.fold(0, _add)),
    );
  }

  static int _add(int a, int b) => a + b;
}
