import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/firestore_message_context_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/firestore_revisor_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/firestore_winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/message_context_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/revisor_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/datasources/winning_numbers_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/matches/data/repositories/firestore_matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/repositories/matches_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/real_summary_providers.dart';

// Capa de datos REAL de Coincidencias (nombres PROVISIONALES), conectada:
// `matchesRepositoryProvider` devuelve `realMatchesRepositoryProvider`. El
// nombre del grupo usa el mismo `groupNameDatasourceProvider` del Resumen
// (con caché de sesión).

final winningNumbersDatasourceProvider = Provider<WinningNumbersDatasource>(
  (ref) => FirestoreWinningNumbersDatasource(ref.watch(firestoreProvider)),
);

final revisorRecordsDatasourceProvider = Provider<RevisorRecordsDatasource>(
  (ref) => FirestoreRevisorRecordsDatasource(ref.watch(firestoreProvider)),
);

final messageContextDatasourceProvider = Provider<MessageContextDatasource>(
  (ref) => FirestoreMessageContextDatasource(ref.watch(firestoreProvider)),
);

final realMatchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => FirestoreMatchesRepository(
    winners: ref.watch(winningNumbersDatasourceProvider),
    records: ref.watch(revisorRecordsDatasourceProvider),
    messages: ref.watch(messageContextDatasourceProvider),
    groupNames: ref.watch(groupNameDatasourceProvider),
  ),
);
