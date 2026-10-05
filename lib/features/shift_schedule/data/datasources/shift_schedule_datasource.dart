import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/errors/firestore_failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Colecciones de este proyecto con los horarios y los festivos. Nombres
/// PROVISIONALES. `jornadas` es la réplica de la del ERP (la copia la función
/// programada); `festivos_colombia` tiene un documento por año con `fechas`.
const shiftScheduleSource = (
  jornadas: 'jornadas',
  festivos: 'festivos_colombia',
  festivosField: 'fechas',
);

/// Id del documento de `jornadas` (el del ERP) → clave de la app.
const jornadaIdToShift = <String, Shift>{
  'manana': Shift.morning,
  'tarde_1': Shift.afternoon1,
  'tarde_2': Shift.afternoon2,
  'noche': Shift.night1,
  'festivos': Shift.holiday,
};

/// Un documento leído: su id y sus datos.
typedef ScheduleDocument = ({String id, Map<String, dynamic> data});

/// Lee todos los documentos de una colección.
typedef CollectionReader =
    Future<List<ScheduleDocument>> Function(String collection);

abstract class ShiftScheduleDatasource {
  /// La tabla armada con `jornadas` y `festivos_colombia`. Nunca lanza.
  Future<Either<Failure, ShiftTable>> fetchShiftTable();
}

/// [ShiftScheduleDatasource] con Firestore: una lectura única (`.get()`, sin
/// `.snapshots()`) de cada colección, como `reviewShiftsProvider`.
class FirestoreShiftScheduleDatasource implements ShiftScheduleDatasource {
  /// Lectura real contra [firestore].
  FirestoreShiftScheduleDatasource(FirebaseFirestore firestore)
    : this.withReader((collection) async {
        final snap = await firestore.collection(collection).get();
        return [for (final doc in snap.docs) (id: doc.id, data: doc.data())];
      });

  /// Con una función de lectura propia (para probar sin Firebase).
  const FirestoreShiftScheduleDatasource.withReader(this._read);

  final CollectionReader _read;

  @override
  Future<Either<Failure, ShiftTable>> fetchShiftTable() async {
    final List<ScheduleDocument> jornadas;
    final List<ScheduleDocument> festivos;
    try {
      jornadas = await _read(shiftScheduleSource.jornadas);
      festivos = await _read(shiftScheduleSource.festivos);
    } on FirebaseException catch (e) {
      return Left(mapFirestoreError(e));
    } catch (_) {
      return const Left(
        Failure.unknown(message: 'Error inesperado al leer las jornadas.'),
      );
    }
    try {
      return Right(parseShiftTable(jornadas: jornadas, festivos: festivos));
    } catch (_) {
      return const Left(
        Failure.unknown(message: 'Error inesperado al armar las jornadas.'),
      );
    }
  }
}

final _timeFormat = RegExp(r'^\d{4}-\d{2}-\d{2}T(\d{2}):(\d{2}):\d{2}\.000$');
final _dateFormat = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// Minutos desde la medianoche de un `yyyy-MM-ddTHH:mm:ss.000` (solo cuentan
/// la hora y el minuto; los segundos se descartan), o `null` si no es texto
/// con ese formato o la hora o el minuto no son válidos.
int? _minutesOf(Object? value) {
  if (value is! String) return null;
  final match = _timeFormat.firstMatch(value);
  if (match == null) return null;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}

bool _isValidDate(Object? value) {
  if (value is! String || !_dateFormat.hasMatch(value)) return false;
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  return parsed != null && parsed.toIso8601String().startsWith(value);
}

/// Arma la tabla a partir de la tabla FIJA ([fixedShiftTable]):
/// - cada documento válido de `jornadas` reemplaza el rango de su jornada
///   (`startTime`/`endTime`; `pendingApproval` y `proposed*` se ignoran);
/// - un documento con hora inválida o con inicio posterior al fin se ignora y
///   esa jornada conserva su rango fijo; un id desconocido se ignora;
/// - los festivos son todas las `fechas` válidas (`yyyy-MM-dd`) de
///   `festivos_colombia`; una fecha inválida se ignora.
/// Nunca lanza por un dato inválido.
ShiftTable parseShiftTable({
  required List<ScheduleDocument> jornadas,
  required List<ScheduleDocument> festivos,
}) {
  final weekday = Map<Shift, ShiftRange>.of(fixedShiftTable.weekdayRanges);
  var holidayRange = fixedShiftTable.holidayRange;

  for (final doc in jornadas) {
    final shift = jornadaIdToShift[doc.id];
    if (shift == null) {
      debugPrint('[JORNADAS] id desconocido "${doc.id}": se ignora');
      continue;
    }
    final start = _minutesOf(doc.data['startTime']);
    final end = _minutesOf(doc.data['endTime']);
    if (start == null || end == null || start > end) {
      debugPrint('[JORNADAS] "${doc.id}" con horario inválido: se ignora');
      continue;
    }
    final range = (start: start, end: end);
    if (shift == Shift.holiday) {
      holidayRange = range;
    } else {
      weekday[shift] = range;
    }
  }

  final holidays = <String>{};
  for (final doc in festivos) {
    final fechas = doc.data[shiftScheduleSource.festivosField];
    if (fechas is! List) {
      debugPrint('[JORNADAS] festivos "${doc.id}" sin lista de fechas');
      continue;
    }
    var invalid = 0;
    for (final fecha in fechas) {
      if (_isValidDate(fecha)) {
        holidays.add(fecha as String);
      } else {
        invalid++;
      }
    }
    if (invalid > 0) {
      debugPrint('[JORNADAS] festivos "${doc.id}": $invalid fechas inválidas');
    }
  }

  return ShiftTable(
    weekdayRanges: {
      for (final shift in fixedShiftTable.weekdayRanges.keys)
        shift: weekday[shift]!,
    },
    holidayRange: holidayRange,
    holidays: holidays,
  );
}
