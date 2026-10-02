import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';

/// Cuánto vale un Resumen ya leído antes de volver a pedirlo a la fuente.
const Duration summaryCacheTtl = Duration(minutes: 5);

/// Cuántas fechas se guardan como máximo.
const int summaryCacheMaxEntries = 10;

typedef SummaryResult = Either<Failure, List<JornadaSummary>>;

/// Caché en memoria del Resumen, por fecha (nombre PROVISIONAL). Dart puro.
///
/// - Clave: la fecha en `yyyy-MM-dd` con [fechaJornadaDe] (el mismo helper
///   que el repositorio).
/// - Solo guarda resultados correctos (`Right`); un `Left` nunca se guarda.
/// - Un valor con edad menor a [ttl] se devuelve sin ir a la fuente.
/// - Una sola lectura por fecha a la vez: quien pide una fecha que ya se
///   está leyendo espera esa misma lectura.
/// - Como máximo [maxEntries] fechas: al pasarse, sale la guardada hace más
///   tiempo.
class SummaryCache {
  SummaryCache({
    required DateTime Function() now,
    this.ttl = summaryCacheTtl,
    this.maxEntries = summaryCacheMaxEntries,
  }) : _now = now;

  final DateTime Function() _now;
  final Duration ttl;
  final int maxEntries;

  /// En orden de guardado: la primera es la más antigua.
  final Map<String, ({DateTime storedAt, List<JornadaSummary> value})>
  _entries = {};
  final Map<String, Future<SummaryResult>> _inFlight = {};

  /// Clave de [fecha] (solo cuenta el día).
  static String keyOf(DateTime fecha) => fechaJornadaDe(
    DateTime(fecha.year, fecha.month, fecha.day).millisecondsSinceEpoch,
  );

  /// El Resumen de [fecha]: el guardado si sigue vigente; si no, [load].
  Future<SummaryResult> get(
    DateTime fecha,
    Future<SummaryResult> Function() load,
  ) {
    final key = keyOf(fecha);

    final entry = _entries[key];
    if (entry != null && _now().difference(entry.storedAt) < ttl) {
      return Future.value(Right(entry.value));
    }

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final completer = Completer<SummaryResult>();
    _inFlight[key] = completer.future;
    _load(key, completer, load);
    return completer.future;
  }

  Future<void> _load(
    String key,
    Completer<SummaryResult> completer,
    Future<SummaryResult> Function() load,
  ) async {
    SummaryResult result;
    try {
      result = await load();
    } catch (_) {
      // La fuente no debería lanzar; si lo hace, es un error más (no se
      // guarda).
      result = const Left(
        Failure.unknown(message: 'Error inesperado al leer el resumen.'),
      );
    }
    // Si se invalidó mientras se leía, este resultado ya no se guarda.
    if (identical(_inFlight[key], completer.future)) {
      _inFlight.remove(key);
      result.fold((_) {}, (value) => _store(key, value));
    }
    completer.complete(result);
  }

  void _store(String key, List<JornadaSummary> value) {
    _entries.remove(key);
    _entries[key] = (storedAt: _now(), value: value);
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  /// Olvida [fecha]: la próxima consulta va a la fuente (también si había
  /// una lectura en curso, cuyo resultado ya no se guarda).
  void invalidate(DateTime fecha) {
    final key = keyOf(fecha);
    _entries.remove(key);
    _inFlight.remove(key);
  }

  /// Olvida todas las fechas.
  void invalidateAll() {
    _entries.clear();
    _inFlight.clear();
  }
}
