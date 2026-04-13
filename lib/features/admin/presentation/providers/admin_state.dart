import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';

part 'admin_state.freezed.dart';

@freezed
abstract class AdminState with _$AdminState {
  const factory AdminState({
    @Default([]) List<AppUser> users,
    @Default([]) List<Group> groups,
    @Default(false) bool isLoadingUsers,
    @Default(false) bool isLoadingGroups,
    @Default(false) bool isSubmitting,
    AdminFailure? error,
    String? successMessage,
  }) = _AdminState;
}
