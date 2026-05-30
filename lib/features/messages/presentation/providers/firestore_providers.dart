import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/datasources/edit_attempts_firestore_datasource.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/datasources/messages_firestore_datasource.dart';

final firestoreProvider = Provider<FirebaseFirestore>(
  (_) => FirebaseFirestore.instance,
);

final editAttemptsDatasourceProvider =
    Provider<EditAttemptsFirestoreDatasource>((ref) {
      final firestore = ref.watch(firestoreProvider);
      return EditAttemptsFirestoreDatasource(firestore);
    });

final messagesFirestoreDatasourceProvider =
    Provider<MessagesFirestoreDatasource>((ref) {
      final firestore = ref.watch(firestoreProvider);
      return MessagesFirestoreDatasource(firestore);
    });
