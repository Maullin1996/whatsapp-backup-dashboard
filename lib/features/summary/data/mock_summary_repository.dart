import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/role_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';

/// Cada escenario fija a la vez el estado de dinero y cuánto registró cada rol
/// frente al contador del bot (`imagenesEnJornada`), para ver las dos señales
/// por separado.
enum _Scenario {
  /// Dinero cuadra, pero a los dos les faltan imágenes.
  cuadra,

  /// Descuadre; el Revisor está al día y al Sumador le falta 1 imagen.
  descuadre,

  /// Dinero cuadra y los dos registraron justo lo que cuenta el bot.
  alDia,

  /// Solo registró el Revisor, y registró MÁS que el contador (sin aviso).
  faltaSumador,

  /// Solo registró el Sumador, al día.
  faltaRevisor,

  /// Dinero cuadra, con registros pero contador 0 (sin aviso).
  sinContador,

  /// Nadie registró (el contador no genera aviso: lo cubre el badge).
  ninguno,
}

/// TEMPORAL — el día que exista subida real a Firestore (paso 7) o el
/// mecanismo de lectura cruzada que se descartó en esta sesión, esta clase se
/// reemplaza por un `SummaryRepository` real. No asumas que los datos de acá
/// reflejan la app de verdad. El dato real de `imagenesEnJornada` es un `get`
/// por id a `shift_image_counts` (ver `shiftImageCountDocId`), no una consulta.
///
/// Genera datos inventados pero DETERMINISTAS por fecha: la fecha es la
/// semilla, así que el mismo día devuelve siempre lo mismo (la UI no cambia
/// al reconstruirse). Siempre incluye un caso que cuadra (con imágenes
/// faltantes), uno con descuadre, uno con ambos al día, uno con el Sumador sin
/// registrar, uno con contador 0 y uno con ambos sin registrar, repartidos en
/// 3 grupos. No modela las jornadas distintas de los domingos.
class MockSummaryRepository implements SummaryRepository {
  /// [latency] simula la espera de una lectura real (para ver el estado de
  /// carga); los tests usan `Duration.zero`.
  const MockSummaryRepository({
    this.latency = const Duration(milliseconds: 400),
  });

  final Duration latency;

  static const _groups = [
    (chatJid: 'mock-grupo-norte@g.us', name: 'Grupo Norte'),
    (chatJid: 'mock-grupo-centro@g.us', name: 'Grupo Centro'),
    (chatJid: 'mock-grupo-sur@g.us', name: 'Grupo Sur'),
  ];

  static const _shifts = [
    Shift.morning,
    Shift.afternoon1,
    Shift.afternoon2,
    Shift.night1,
  ];

  @override
  Future<Either<Failure, List<JornadaSummary>>> getJornadaSummaries(
    DateTime fecha,
  ) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return Right(_generate(fecha));
  }

  List<JornadaSummary> _generate(DateTime fecha) {
    final day = DateTime(fecha.year, fecha.month, fecha.day);
    final random = Random(day.year * 10000 + day.month * 100 + day.day);
    final fechaJornada = fechaJornadaDe(day.millisecondsSinceEpoch);

    // Los casos de siempre, más 0-2 al azar; repartidos entre los grupos.
    final scenarios = [
      _Scenario.cuadra,
      _Scenario.descuadre,
      _Scenario.alDia,
      _Scenario.faltaSumador,
      _Scenario.sinContador,
      _Scenario.ninguno,
      for (var i = random.nextInt(3); i > 0; i--)
        _Scenario.values[random.nextInt(_Scenario.values.length)],
    ]..shuffle(random);

    // Cada grupo usa jornadas distintas, en un orden propio.
    final shiftsByGroup = [
      for (final _ in _groups) [..._shifts]..shuffle(random),
    ];
    final used = List.filled(_groups.length, 0);

    final result = <(int, Shift, JornadaSummary)>[];
    for (var i = 0; i < scenarios.length; i++) {
      final groupIndex = i % _groups.length;
      final shift = shiftsByGroup[groupIndex][used[groupIndex]++];
      final group = _groups[groupIndex];
      final (revisor, sumador, imagenesEnJornada) = _roles(
        scenarios[i],
        random,
      );
      result.add((
        groupIndex,
        shift,
        JornadaSummary(
          chatJid: group.chatJid,
          groupName: group.name,
          fechaJornada: fechaJornada,
          shift: shiftNames[shift]!,
          revisor: revisor,
          sumador: sumador,
          imagenesEnJornada: imagenesEnJornada,
        ),
      ));
    }

    result.sort((a, b) {
      final byGroup = a.$1.compareTo(b.$1);
      return byGroup != 0 ? byGroup : a.$2.index.compareTo(b.$2.index);
    });
    return [for (final r in result) r.$3];
  }

  /// Lo que registró cada rol y el contador del bot para la jornada.
  (RoleSummary, RoleSummary, int) _roles(_Scenario scenario, Random random) {
    final tickets = 3 + random.nextInt(10);
    // Mínimo 2: algunos escenarios necesitan que un rol registre una menos.
    final imagenes = 2 + random.nextInt(tickets - 1);
    final total = tickets * (5 + random.nextInt(26)) * 1000;

    RoleSummary registrado(int totalSuma, [int? cantidadImagenes]) =>
        RoleSummary(
          registrado: true,
          cantidadImagenes: cantidadImagenes ?? imagenes,
          cantidadTickets: tickets,
          totalSuma: totalSuma,
        );

    return switch (scenario) {
      _Scenario.cuadra => (
        registrado(total),
        registrado(total),
        imagenes + 1 + random.nextInt(3),
      ),
      _Scenario.descuadre => (
        registrado(total),
        registrado(
          total + (random.nextBool() ? 1 : -1) * (1 + random.nextInt(9)) * 1000,
          imagenes - 1,
        ),
        imagenes,
      ),
      _Scenario.alDia => (registrado(total), registrado(total), imagenes),
      _Scenario.faltaSumador => (
        registrado(total),
        RoleSummary.sinRegistrar,
        imagenes - 1,
      ),
      _Scenario.faltaRevisor => (
        RoleSummary.sinRegistrar,
        registrado(total),
        imagenes,
      ),
      _Scenario.sinContador => (registrado(total), registrado(total), 0),
      _Scenario.ninguno => (
        RoleSummary.sinRegistrar,
        RoleSummary.sinRegistrar,
        1 + random.nextInt(4),
      ),
    };
  }
}
