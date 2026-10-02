import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/app/providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/cached_group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/firestore_summary_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/group_name_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/shift_image_counts_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/datasources/summary_records_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/summary/data/repositories/firestore_summary_repository.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/repositories/summary_repository.dart';

// Capa de datos REAL del Resumen (nombres PROVISIONALES), conectada:
// `summaryRepositoryProvider` devuelve `realSummaryRepositoryProvider`.

final summaryRecordsDatasourceProvider = Provider<SummaryRecordsDatasource>(
  (ref) => FirestoreSummaryRecordsDatasource(ref.watch(firestoreProvider)),
);

final shiftImageCountsDatasourceProvider = Provider<ShiftImageCountsDatasource>(
  (ref) => FirestoreShiftImageCountsDatasource(ref.watch(firestoreProvider)),
);

/// Con los nombres encontrados guardados toda la sesión (no los ausentes ni
/// los errores).
final groupNameDatasourceProvider = Provider<GroupNameDatasource>(
  (ref) => CachedGroupNameDatasource(
    FirestoreGroupNameDatasource(ref.watch(firestoreProvider)),
  ),
);

final realSummaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => FirestoreSummaryRepository(
    records: ref.watch(summaryRecordsDatasourceProvider),
    counts: ref.watch(shiftImageCountsDatasourceProvider),
    groupNames: ref.watch(groupNameDatasourceProvider),
  ),
);
