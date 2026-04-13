import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/theme/app_colors.dart';
import 'package:whatsapp_monitor_viewer/features/admin/domain/entities/app_user.dart';
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
    final isSubmitting = state.isSubmitting;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    // En mobile la lista ocupa menos altura para que el dialog no tape toda la pantalla
    final listMaxHeight = isMobile ? 300.0 : 400.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 80,
        vertical: 24,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Asignar grupos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 18 : 20,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.user.displayName,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              SizedBox(height: isMobile ? 12 : 16),
              state.isLoadingGroups
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : state.groups.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No hay grupos disponibles'),
                    )
                  : ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: listMaxHeight),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: state.groups.length,
                        itemBuilder: (context, index) {
                          final group = state.groups[index];
                          final isSelected = _selected.contains(group.chatJid);
                          return CheckboxListTile(
                            dense: isMobile,
                            value: isSelected,
                            activeColor: AppColors.primaryGreen,
                            title: Text(
                              group.groupName,
                              style: TextStyle(fontSize: isMobile ? 13 : 15),
                            ),
                            subtitle: Text(
                              group.chatJid,
                              style: const TextStyle(fontSize: 11),
                            ),
                            onChanged: isSubmitting
                                ? null
                                : (checked) => setState(() {
                                    if (checked == true) {
                                      _selected.add(group.chatJid);
                                    } else {
                                      _selected.remove(group.chatJid);
                                    }
                                  }),
                          );
                        },
                      ),
                    ),
              SizedBox(height: isMobile ? 12 : 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
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
                    onPressed: isSubmitting ? null : _submit,
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
