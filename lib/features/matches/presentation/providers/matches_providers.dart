import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure_log.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/all_groups_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/day_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/group_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/lottery_results.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/real_matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';

/// Día de las Coincidencias (solo la fecha, sin hora). Arranca en hoy.
class MatchesDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateUtils.dateOnly(DateTime.now());

  void select(DateTime date) => state = DateUtils.dateOnly(date);

  void today() => state = DateUtils.dateOnly(DateTime.now());
}

final matchesDateProvider = NotifierProvider<MatchesDateNotifier, DateTime>(
  MatchesDateNotifier.new,
);

/// Repositorio de Coincidencias: el real (ganadores de `winning_numbers`,
/// registros del Revisor de `image_reviews`, mensajes y nombres de grupo,
/// ver `real_matches_providers.dart`). Los tests lo sobreescriben.
final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => ref.watch(realMatchesRepositoryProvider),
);

/// Coincidencias del día elegido, por jornada. Se recalcula al cambiar
/// [matchesDateProvider]; cada fecha se consulta de forma independiente, sin
/// acumular con la anterior (`image-review-domain`, regla 5). Un `Failure`
/// queda como error del `AsyncValue`, sin reintento automático (no es
/// transitorio).
final dayMatchesProvider = FutureProvider<DayMatches>((ref) async {
  final date = ref.watch(matchesDateProvider);
  final result = await ref.watch(matchesRepositoryProvider).getMatches(date);
  return result.fold((failure) {
    debugPrint(failureLogLine('COINCIDENCIAS', failure));
    throw failure;
  }, (day) => day);
}, retry: (retryCount, error) => null);

/// Todos los grupos conocidos (`group_stats`), para listar también los que
/// tienen 0 ganadores. Si la lectura falla la lista queda vacía: la pantalla
/// muestra al menos los grupos con ganadores.
final allGroupsProvider = FutureProvider<List<KnownGroup>>((ref) async {
  final result = await ref.watch(allGroupsDatasourceProvider).fetchAll();
  return result.fold((failure) {
    debugPrint(failureLogLine('COINCIDENCIAS', failure));
    return const <KnownGroup>[];
  }, (groups) => groups);
});

/// Un [GroupMatches] por grupo del día elegido: los que tuvieron ganadores y
/// los que no (con 0). Espera a las coincidencias y a la lista de grupos.
final groupMatchesListProvider = FutureProvider<List<GroupMatches>>((
  ref,
) async {
  final day = await ref.watch(dayMatchesProvider.future);
  final groups = await ref.watch(allGroupsProvider.future);
  return groupMatchesOf(
    day,
    knownGroups: {for (final g in groups) g.chatJid: g.groupName},
  );
}, retry: (retryCount, error) => null);

/// Resumen de loterías y números ganadores del día elegido; vacío mientras
/// carga o si el día no tiene ganadores.
final dayLotteryResultsProvider = Provider<List<LotteryResult>>((ref) {
  final day = ref.watch(dayMatchesProvider).value;
  return day == null ? const [] : lotteryResultsOf(day);
});

/// Imágenes de los ganadores de un grupo, para el visor de imágenes (una por
/// mensaje, aunque tenga varios números ganadores), en el orden de la lista
/// del detalle. Vacía mientras el día no está cargado.
final groupImageItemsProvider = Provider.family<List<ImageViewItem>, String>((
  ref,
  chatJid,
) {
  final day = ref.watch(dayMatchesProvider).value;
  if (day == null) return const [];
  final group = groupMatchesOf(
    day,
  ).where((g) => g.chatJid == chatJid).firstOrNull;
  if (group == null) return const [];
  final seen = <String>{};
  return [
    for (final m in group.matches)
      if (seen.add(m.messageId))
        ImageViewItem(
          messageId: m.messageId,
          chatJid: m.chatJid,
          storagePath: m.storagePath,
          senderName: m.senderName,
          // El visor no usa la marca de tiempo para mostrar nada aquí.
          messageTimestamp: 0,
          localTime: m.localTime,
          shift: m.shift,
          fechaJornada: m.fechaJornada,
        ),
  ];
});
