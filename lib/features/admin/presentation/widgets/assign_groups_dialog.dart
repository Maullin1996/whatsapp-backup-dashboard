import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/errors/admin_failure.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/widgets/group_shifts_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';

class AssignGroupsDialog extends ConsumerStatefulWidget {
  final AppUser user;
  const AssignGroupsDialog({super.key, required this.user});

  @override
  ConsumerState<AssignGroupsDialog> createState() => _AssignGroupsDialogState();
}

class _AssignGroupsDialogState extends ConsumerState<AssignGroupsDialog> {
  late Set<String> _selected;

  /// Horarios elegidos por `chatJid`, en memoria hasta el Guardar general —
  /// independiente de `_selected`: si se desmarca un grupo y se vuelve a
  /// marcar antes de Guardar, sus horarios reaparecen tal cual. Inicializada
  /// una sola vez, al abrir el diálogo, desde `widget.user.reviewShifts`.
  late Map<String, List<Shift>> _shiftsByChatJid;

  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.user.allowedGroups);
    _shiftsByChatJid = <String, List<Shift>>{};
    for (final rs in widget.user.reviewShifts) {
      _shiftsByChatJid.putIfAbsent(rs.chatJid, () => []).add(rs.shift);
    }
  }

  /// Solo las entradas cuyo grupo sigue marcado en `_selected` — un grupo
  /// desmarcado antes de Guardar no manda sus horarios, aunque sigan en
  /// memoria por si se vuelve a marcar.
  List<ReviewShift> _shiftsPayload() => [
    for (final entry in _shiftsByChatJid.entries)
      if (_selected.contains(entry.key))
        for (final shift in entry.value)
          ReviewShift(chatJid: entry.key, shift: shift),
  ];

  Future<void> _openHorarios(Group group) async {
    final role = widget.user.reviewRole;
    if (role == null) return; // el botón no debería mostrarse sin rol

    // AdminState.users ya trae reviewRole+reviewShifts de todos los
    // usuarios (mismo listUsers), sin llamada extra.
    final users = ref.read(adminProvider).users;
    final taken = <Shift, String>{};
    for (final other in users) {
      if (other.uid == widget.user.uid) continue;
      if (other.reviewRole != role) continue;
      for (final s in other.reviewShifts) {
        if (s.chatJid == group.chatJid) taken[s.shift] = other.email;
      }
    }

    final result = await showDialog<Set<Shift>>(
      context: context,
      builder: (_) => GroupShiftsDialog(
        groupName: group.groupName,
        initialShifts: Set.of(_shiftsByChatJid[group.chatJid] ?? const []),
        takenByOthers: taken,
      ),
    );
    if (result == null || !mounted) return; // canceló
    setState(() => _shiftsByChatJid[group.chatJid] = result.toList());
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    await ref
        .read(adminProvider.notifier)
        .updateUserGroups(
          uid: widget.user.uid,
          allowedGroups: _selected.toList(),
        );
    if (!mounted) return;

    if (widget.user.reviewRole == null) {
      Navigator.of(context).pop();
      return;
    }

    final result = await ref
        .read(adminProvider.notifier)
        .updateReviewShifts(uid: widget.user.uid, shifts: _shiftsPayload());
    if (!mounted) return;

    result.fold(
      (failure) => setState(() {
        _submitting = false;
        _submitError = failure.message;
      }),
      (_) => Navigator.of(context).pop(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);

    return ResponsiveLayout(
      mobile: _AssignGroupsDialogMobile(
        userName: widget.user.displayName,
        selected: _selected,
        reviewRole: widget.user.reviewRole,
        shiftsByChatJid: _shiftsByChatJid,
        isSubmitting: _submitting,
        isLoadingGroups: state.isLoadingGroups,
        groups: state.groups,
        errorMessage: _submitError,
        onSubmit: _submit,
        onCancel: () => Navigator.of(context).pop(),
        onGroupToggle: (chatJid, checked) => setState(() {
          if (checked) {
            _selected.add(chatJid);
          } else {
            _selected.remove(chatJid);
          }
        }),
        onHorarios: _openHorarios,
      ),
      desktop: _AssignGroupsDialogDesktop(
        userName: widget.user.displayName,
        selected: _selected,
        reviewRole: widget.user.reviewRole,
        shiftsByChatJid: _shiftsByChatJid,
        isSubmitting: _submitting,
        isLoadingGroups: state.isLoadingGroups,
        groups: state.groups,
        errorMessage: _submitError,
        onSubmit: _submit,
        onCancel: () => Navigator.of(context).pop(),
        onGroupToggle: (chatJid, checked) => setState(() {
          if (checked) {
            _selected.add(chatJid);
          } else {
            _selected.remove(chatJid);
          }
        }),
        onHorarios: _openHorarios,
      ),
    );
  }
}

class _AssignGroupsDialogMobile extends StatelessWidget {
  final String userName;
  final Set<String> selected;
  final ReviewRole? reviewRole;
  final Map<String, List<Shift>> shiftsByChatJid;
  final bool isSubmitting;
  final bool isLoadingGroups;
  final List<Group> groups;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final void Function(String chatJid, bool checked) onGroupToggle;
  final void Function(Group group) onHorarios;

  const _AssignGroupsDialogMobile({
    required this.userName,
    required this.selected,
    required this.reviewRole,
    required this.shiftsByChatJid,
    required this.isSubmitting,
    required this.isLoadingGroups,
    required this.groups,
    required this.errorMessage,
    required this.onSubmit,
    required this.onCancel,
    required this.onGroupToggle,
    required this.onHorarios,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Asignar grupos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: AppSpacing.md),
              isLoadingGroups
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : groups.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text('No hay grupos disponibles'),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final isSelected = selected.contains(group.chatJid);
                          return _GroupRow(
                            group: group,
                            isSelected: isSelected,
                            isSubmitting: isSubmitting,
                            showHorarios: isSelected && reviewRole != null,
                            shiftsCount:
                                shiftsByChatJid[group.chatJid]?.length ?? 0,
                            titleFontSize: 13,
                            subtitleFontSize: 11,
                            onToggle: (checked) =>
                                onGroupToggle(group.chatJid, checked),
                            onHorarios: () => onHorarios(group),
                          );
                        },
                      ),
                    ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  errorMessage!,
                  style: TextStyle(color: AppColors.errorMessage, fontSize: 13),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting ? null : onCancel,
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(90, 44),
                    ),
                    onPressed: isSubmitting ? null : onSubmit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignGroupsDialogDesktop extends StatelessWidget {
  final String userName;
  final Set<String> selected;
  final ReviewRole? reviewRole;
  final Map<String, List<Shift>> shiftsByChatJid;
  final bool isSubmitting;
  final bool isLoadingGroups;
  final List<Group> groups;
  final String? errorMessage;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final void Function(String chatJid, bool checked) onGroupToggle;
  final void Function(Group group) onHorarios;

  const _AssignGroupsDialogDesktop({
    required this.userName,
    required this.selected,
    required this.reviewRole,
    required this.shiftsByChatJid,
    required this.isSubmitting,
    required this.isLoadingGroups,
    required this.groups,
    required this.errorMessage,
    required this.onSubmit,
    required this.onCancel,
    required this.onGroupToggle,
    required this.onHorarios,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 80,
        vertical: AppSpacing.xl,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Asignar grupos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: AppSpacing.lg),
              isLoadingGroups
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : groups.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                      child: Text('No hay grupos disponibles'),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final isSelected = selected.contains(group.chatJid);
                          return _GroupRow(
                            group: group,
                            isSelected: isSelected,
                            isSubmitting: isSubmitting,
                            showHorarios: isSelected && reviewRole != null,
                            shiftsCount:
                                shiftsByChatJid[group.chatJid]?.length ?? 0,
                            titleFontSize: 15,
                            subtitleFontSize: 11,
                            onToggle: (checked) =>
                                onGroupToggle(group.chatJid, checked),
                            onHorarios: () => onHorarios(group),
                          );
                        },
                      ),
                    ),
              if (errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  errorMessage!,
                  style: TextStyle(color: AppColors.errorMessage, fontSize: 13),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting ? null : onCancel,
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(90, 44),
                    ),
                    onPressed: isSubmitting ? null : onSubmit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Guardar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de un grupo: checkbox + nombre/chatJid + botón "Horarios" opcional.
/// Reemplaza a `CheckboxListTile` (que solo tiene un slot extra, insuficiente
/// para un segundo control interactivo) en mobile y desktop.
class _GroupRow extends StatelessWidget {
  final Group group;
  final bool isSelected;
  final bool isSubmitting;
  final bool showHorarios;
  final int shiftsCount;
  final double titleFontSize;
  final double subtitleFontSize;
  final ValueChanged<bool> onToggle;
  final VoidCallback onHorarios;

  const _GroupRow({
    required this.group,
    required this.isSelected,
    required this.isSubmitting,
    required this.showHorarios,
    required this.shiftsCount,
    required this.titleFontSize,
    required this.subtitleFontSize,
    required this.onToggle,
    required this.onHorarios,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: isSelected,
          activeColor: AppColors.primaryGreen,
          onChanged: isSubmitting
              ? null
              : (checked) => onToggle(checked ?? false),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                group.groupName,
                style: TextStyle(fontSize: titleFontSize),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                group.chatJid,
                style: TextStyle(fontSize: subtitleFontSize),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (showHorarios)
          TextButton(
            onPressed: isSubmitting ? null : onHorarios,
            child: Text(
              shiftsCount > 0 ? 'Horarios ($shiftsCount)' : 'Horarios',
            ),
          ),
      ],
    );
  }
}
