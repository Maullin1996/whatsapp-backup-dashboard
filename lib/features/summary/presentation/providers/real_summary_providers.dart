import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_summary_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/summary_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/repositories/firestore_summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';

// Capa de datos REAL del Resumen (nombres PROVISIONALES). TODAVÍA NO
// CONECTADA: ningún código los lee y `summaryRepositoryProvider` sigue en el
// mock. Conectarla es cambiar ese provider para que devuelva
// `ref.watch(realSummaryRepositoryProvider)`.

final summaryRecordsDatasourceProvider = Provider<SummaryRecordsDatasource>(
  (ref) => FirestoreSummaryRecordsDatasource(ref.watch(firestoreProvider)),
);

final shiftImageCountsDatasourceProvider = Provider<ShiftImageCountsDatasource>(
  (ref) => FirestoreShiftImageCountsDatasource(ref.watch(firestoreProvider)),
);

final groupNameDatasourceProvider = Provider<GroupNameDatasource>(
  (ref) => FirestoreGroupNameDatasource(ref.watch(firestoreProvider)),
);

final realSummaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => FirestoreSummaryRepository(
    records: ref.watch(summaryRecordsDatasourceProvider),
    counts: ref.watch(shiftImageCountsDatasourceProvider),
    groupNames: ref.watch(groupNameDatasourceProvider),
  ),
);
