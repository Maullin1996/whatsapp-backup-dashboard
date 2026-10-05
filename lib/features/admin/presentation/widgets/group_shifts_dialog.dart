import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Jornadas asignables a un Revisor/Sumador: todas menos [Shift.outOfShift],
/// que no es un turno real, y menos [Shift.night2] (no está en la tabla),
/// aunque `ASSIGNABLE_SHIFTS` de `functions/index.js` todavía la acepte.
final List<Shift> assignableShifts = Shift.values
    .where((s) => s != Shift.outOfShift && s != Shift.night2)
    .toList(growable: false);

/// Diálogo anidado (se abre sobre `AssignGroupsDialog`, patrón consistente
/// con el resto del panel — ver `.claude/skills/image-review-roles.md`) para
/// elegir las jornadas que un Revisor/Sumador cubre en UN grupo puntual.
///
/// Puramente de estado local: no llama a ninguna Cloud Function. Devuelve la
/// selección (`Navigator.pop(selected)`) al diálogo padre, que la guarda en
/// memoria hasta que se pulse "Guardar" ahí. Las jornadas ya cubiertas por
/// OTRA persona del MISMO rol llegan deshabilitadas, con el email de quién
/// las tiene, para coordinar entre superAdmins sin esperar el rechazo del
/// servidor.
class GroupShiftsDialog extends StatefulWidget {
  final String groupName;
  final Set<Shift> initialShifts;
  final Map<Shift, String> takenByOthers;

  const GroupShiftsDialog({
    super.key,
    required this.groupName,
    required this.initialShifts,
    required this.takenByOthers,
  });

  @override
  State<GroupShiftsDialog> createState() => _GroupShiftsDialogState();
}

class _GroupShiftsDialogState extends State<GroupShiftsDialog> {
  late Set<Shift> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.initialShifts);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Horarios · ${widget.groupName}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final shift in assignableShifts)
              CheckboxListTile(
                dense: true,
                value: _selected.contains(shift),
                activeColor: AppColors.primaryGreen,
                title: Text(shortShiftName(shiftNames[shift]!)),
                subtitle: widget.takenByOthers.containsKey(shift)
                    ? Text(
                        'Ya asignado a ${widget.takenByOthers[shift]}',
                        style: const TextStyle(
                          color: AppColors.errorMessage,
                          fontSize: 11,
                        ),
                      )
                    : null,
                onChanged: widget.takenByOthers.containsKey(shift)
                    ? null
                    : (checked) => setState(() {
                        if (checked ?? false) {
                          _selected.add(shift);
                        } else {
                          _selected.remove(shift);
                        }
                      }),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.green)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_selected),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
