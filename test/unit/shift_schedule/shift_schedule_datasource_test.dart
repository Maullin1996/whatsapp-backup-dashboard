import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/shift_schedule/data/datasources/shift_schedule_datasource.dart';

/// Datasource de horarios y festivos con datos falsos, sin Firebase.

Map<String, dynamic> _jornada(String start, String end) => {
  'name': 'x',
  'startTime': start,
  'endTime': end,
  'pendingApproval': false,
  'proposedBy': null,
  'proposedStartTime': null,
  'proposedEndTime': null,
};

/// Los 5 documentos tal como están hoy en el ERP.
List<ScheduleDocument> _validJornadas() => [
  (
    id: 'festivos',
    data: _jornada('2026-02-16T06:00:00.000', '2026-02-16T19:15:00.000'),
  ),
  (
    id: 'manana',
    data: _jornada('2026-09-30T05:30:00.000', '2026-09-30T10:51:00.000'),
  ),
  (
    id: 'noche',
    data: _jornada('2026-08-13T15:28:00.000', '2026-08-13T22:15:00.000'),
  ),
  (
    id: 'tarde_1',
    data: _jornada('2026-02-16T10:58:00.000', '2026-02-16T13:55:00.000'),
  ),
  (
    id: 'tarde_2',
    data: _jornada('2026-02-16T14:01:00.000', '2026-02-16T15:20:00.000'),
  ),
];

List<ScheduleDocument> _validFestivos() => [
  (
    id: '2026',
    data: {
      'fechas': ['2026-01-01', '2026-10-12'],
    },
  ),
  (
    id: '2027',
    data: {
      'fechas': ['2027-01-01'],
    },
  ),
];

FirestoreShiftScheduleDatasource _datasource({
  List<ScheduleDocument>? jornadas,
  List<ScheduleDocument>? festivos,
  Object? error,
  List<String>? requested,
}) => FirestoreShiftScheduleDatasource.withReader((collection) async {
  requested?.add(collection);
  if (error != null) throw error;
  return collection == shiftScheduleSource.jornadas
      ? (jornadas ?? _validJornadas())
      : (festivos ?? _validFestivos());
});

void main() {
  tearDown(restoreFixedShiftTable);

  Future<ShiftTable> fetch(FirestoreShiftScheduleDatasource ds) async {
    final result = await ds.fetchShiftTable();
    return result.fold((f) => fail('se esperaba Right: $f'), (t) => t);
  }

  test('lee las dos colecciones', () async {
    final requested = <String>[];
    await fetch(_datasource(requested: requested));
    expect(requested, ['jornadas', 'festivos_colombia']);
  });

  test('documentos válidos: los rangos del ERP (iguales a la fija) y los '
      'festivos', () async {
    final table = await fetch(_datasource());
    expect(table.weekdayRanges, fixedShiftTable.weekdayRanges);
    expect(table.holidayRange, fixedShiftTable.holidayRange);
    expect(table.holidays, {'2026-01-01', '2026-10-12', '2027-01-01'});
    // Las jornadas siguen en orden del día.
    expect(table.weekdayRanges.keys.toList(), [
      Shift.morning,
      Shift.afternoon1,
      Shift.afternoon2,
      Shift.night1,
    ]);
  });

  test('un horario distinto reemplaza el rango; los segundos se '
      'descartan', () async {
    final jornadas = _validJornadas()
      ..removeWhere((d) => d.id == 'manana')
      ..add((
        id: 'manana',
        data: _jornada('2026-10-03T05:00:30.000', '2026-10-03T10:45:59.000'),
      ));
    final table = await fetch(_datasource(jornadas: jornadas));
    expect(table.weekdayRanges[Shift.morning], (
      start: 5 * 60,
      end: 10 * 60 + 45,
    ));
    expect(table.weekdayRanges.keys.first, Shift.morning);
  });

  test('pendingApproval y proposed* se ignoran', () async {
    final data = _jornada('2026-09-30T05:30:00.000', '2026-09-30T10:51:00.000')
      ..['pendingApproval'] = true
      ..['proposedStartTime'] = '2026-10-03T04:00:00.000'
      ..['proposedEndTime'] = '2026-10-03T09:00:00.000';
    final jornadas = _validJornadas()
      ..removeWhere((d) => d.id == 'manana')
      ..add((id: 'manana', data: data));
    final table = await fetch(_datasource(jornadas: jornadas));
    expect(
      table.weekdayRanges[Shift.morning],
      fixedShiftTable.weekdayRanges[Shift.morning],
    );
  });

  for (final (label, start, end) in [
    ('startTime no es texto', 123, '2026-09-30T10:45:00.000'),
    ('endTime null', '2026-09-30T05:00:00.000', null),
    ('formato distinto', '2026-09-30 05:00', '2026-09-30T10:45:00.000'),
    ('con zona horaria', '2026-09-30T05:00:00.000Z', '2026-09-30T10:45:00.000'),
    ('hora 24', '2026-09-30T24:00:00.000', '2026-09-30T10:45:00.000'),
    ('minuto 60', '2026-09-30T05:60:00.000', '2026-09-30T10:45:00.000'),
    (
      'inicio posterior al fin',
      '2026-09-30T11:00:00.000',
      '2026-09-30T10:45:00.000',
    ),
  ]) {
    test('manana con $label: se ignora y conserva su rango fijo', () async {
      final jornadas = _validJornadas()
        ..removeWhere((d) => d.id == 'manana')
        ..add((
          id: 'manana',
          data: {..._jornada('', ''), 'startTime': start, 'endTime': end},
        ));
      final table = await fetch(_datasource(jornadas: jornadas));
      expect(
        table.weekdayRanges[Shift.morning],
        fixedShiftTable.weekdayRanges[Shift.morning],
      );
    });
  }

  test('festivos con horario inválido: holiday conserva su rango fijo, y las '
      'demás jornadas se cargan', () async {
    final jornadas = _validJornadas()
      ..removeWhere((d) => d.id == 'festivos' || d.id == 'noche')
      ..add((id: 'festivos', data: _jornada('x', 'y')))
      ..add((
        id: 'noche',
        data: _jornada('2026-10-03T15:30:00.000', '2026-10-03T22:00:00.000'),
      ));
    final table = await fetch(_datasource(jornadas: jornadas));
    expect(table.holidayRange, fixedShiftTable.holidayRange);
    expect(table.weekdayRanges[Shift.night1], (
      start: 15 * 60 + 30,
      end: 22 * 60,
    ));
  });

  test('un id desconocido se ignora; una jornada ausente conserva la '
      'fija', () async {
    final jornadas = _validJornadas()
      ..removeWhere((d) => d.id == 'tarde_2')
      ..add((
        id: 'noche_2',
        data: _jornada('2026-10-03T22:25:00.000', '2026-10-03T22:30:00.000'),
      ));
    final table = await fetch(_datasource(jornadas: jornadas));
    expect(table.weekdayRanges, fixedShiftTable.weekdayRanges);
    expect(table.holidayRange, fixedShiftTable.holidayRange);
  });

  test('festivos con formato inválido se ignoran', () async {
    final table = await fetch(
      _datasource(
        festivos: [
          (
            id: '2026',
            data: {
              'fechas': [
                '2026-10-12',
                '2026-02-30', // no existe
                '12/10/2026',
                '2026-1-5',
                '2026-10-12T00:00:00',
                20261012,
                null,
              ],
            },
          ),
          (id: '2027', data: {'fechas': 'no es lista'}),
          (id: '2028', data: <String, dynamic>{}),
        ],
      ),
    );
    expect(table.holidays, {'2026-10-12'});
  });

  test('colecciones vacías: la tabla fija', () async {
    final table = await fetch(_datasource(jornadas: [], festivos: []));
    expect(table, fixedShiftTable);
  });

  test('la lectura que falla devuelve Left sin lanzar y sin tocar la tabla '
      'activa', () async {
    final before = activeShiftTable;
    final denied = await _datasource(
      error: FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      ),
    ).fetchShiftTable();
    expect(denied.isLeft(), isTrue);
    denied.fold((f) => expect(f, const Failure.unauthorized()), (_) {});

    final other = await _datasource(error: StateError('x')).fetchShiftTable();
    expect(other.isLeft(), isTrue);
    other.fold((f) => expect(f, isA<Failure>()), (_) {});

    expect(identical(activeShiftTable, before), isTrue);
  });
}
