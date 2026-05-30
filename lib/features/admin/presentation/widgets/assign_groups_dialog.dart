import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/group.dart';
import 'package:whatsapp_monitor_viewer/features/admin/presentation/providers/admin_providers.dart';

class AssignGroupsDialog extends ConsumerStatefulWidget {
  final AppUser user;
  const AssignGroupsDialog({super.key, required this.user});

  @override
  ConsumerState<AssignGroupsDialog> createState() => _AssignGroupsDialogState();
}

class _AssignGroupsDialogState extends ConsumerState<AssignGroupsDialog> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.from(widget.user.allowedGroups);
  }

  Future<void> _submit() async {
    await ref
        .read(adminProvider.notifier)
        .updateUserGroups(
          uid: widget.user.uid,
          allowedGroups: _selected.toList(),
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminProvider);

    return ResponsiveLayout(
      mobile: _AssignGroupsDialogMobile(
        userName: widget.user.displayName,
        selected: _selected,
        isSubmitting: state.isSubmitting,
        isLoadingGroups: state.isLoadingGroups,
        groups: state.groups,
        onSubmit: _submit,
        onCancel: () => Navigator.of(context).pop(),
        onGroupToggle: (chatJid, checked) => setState(() {
          if (checked) {
            _selected.add(chatJid);
          } else {
            _selected.remove(chatJid);
          }
        }),
      ),
      desktop: _AssignGroupsDialogDesktop(
        userName: widget.user.displayName,
        selected: _selected,
        isSubmitting: state.isSubmitting,
        isLoadingGroups: state.isLoadingGroups,
        groups: state.groups,
        onSubmit: _submit,
        onCancel: () => Navigator.of(context).pop(),
        onGroupToggle: (chatJid, checked) => setState(() {
          if (checked) {
            _selected.add(chatJid);
          } else {
            _selected.remove(chatJid);
          }
        }),
      ),
    );
  }
}

class _AssignGroupsDialogMobile extends StatelessWidget {
  final String userName;
  final Set<String> selected;
  final bool isSubmitting;
  final bool isLoadingGroups;
  final List<Group> groups;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final void Function(String chatJid, bool checked) onGroupToggle;

  const _AssignGroupsDialogMobile({
    required this.userName,
    required this.selected,
    required this.isSubmitting,
    required this.isLoadingGroups,
    required this.groups,
    required this.onSubmit,
    required this.onCancel,
    required this.onGroupToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              const SizedBox(height: 12),
              isLoadingGroups
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : groups.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
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
                          return CheckboxListTile(
                            dense: true,
                            value: isSelected,
                            activeColor: AppColors.primaryGreen,
                            title: Text(
                              group.groupName,
                              style: const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              group.chatJid,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onChanged: isSubmitting
                                ? null
                                : (checked) =>
                                    onGroupToggle(group.chatJid, checked ?? false),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 12),
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
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(90, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
  final bool isSubmitting;
  final bool isLoadingGroups;
  final List<Group> groups;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final void Function(String chatJid, bool checked) onGroupToggle;

  const _AssignGroupsDialogDesktop({
    required this.userName,
    required this.selected,
    required this.isSubmitting,
    required this.isLoadingGroups,
    required this.groups,
    required this.onSubmit,
    required this.onCancel,
    required this.onGroupToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 16),
              isLoadingGroups
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : groups.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
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
                          return CheckboxListTile(
                            dense: false,
                            value: isSelected,
                            activeColor: AppColors.primaryGreen,
                            title: Text(
                              group.groupName,
                              style: const TextStyle(fontSize: 15),
                            ),
                            subtitle: Text(
                              group.chatJid,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onChanged: isSubmitting
                                ? null
                                : (checked) =>
                                    onGroupToggle(group.chatJid, checked ?? false),
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 16),
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
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(90, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
