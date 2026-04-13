import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/datasources/admin_datasource_impl.dart';
import 'package:whatsapp_monitor_viewer/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/repositories/admin_repository.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_notifier.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_state.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepositoryImpl(AdminDatasourceImpl(FirebaseFunctions.instance));
});

final adminProvider = NotifierProvider<AdminNotifier, AdminState>(
  AdminNotifier.new,
);
