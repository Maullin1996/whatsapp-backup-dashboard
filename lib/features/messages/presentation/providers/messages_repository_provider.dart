import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/data/repositories/messages_repository_impl.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/repositories/messages_repository.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/firestore_providers.dart';

final messagesRepositoryProvider = Provider<MessagesRepository>((ref) {
  final datasource = ref.watch(messagesFirestoreDatasourceProvider);
  return MessagesRepositoryImpl(datasource: datasource);
});
