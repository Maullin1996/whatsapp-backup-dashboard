import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';

/// Jornadas asignables a un Revisor/Sumador en el instante [nowMs]: todas
/// menos [Shift.outOfShift], que no es un turno real, y menos [Shift.night2]
/// cuando rige la tabla nueva (no existe en ella), aunque
/// `ASSIGNABLE_SHIFTS` de `functions/index.js` todavía la acepte.
List<Shift> assignableShiftsAt(
  int nowMs, {
  int? effectiveFromMs = newShiftsEffectiveFromMs,
}) {
  final newTable = usesNewShiftTable(nowMs, effectiveFromMs: effectiveFromMs);
  return Shift.values
      .where((s) => s != Shift.outOfShift && !(newTable && s == Shift.night2))
      .toList(growable: false);
}

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
    // Etiquetas y jornadas de la tabla que rige ahora.
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final names = shiftNamesAt(nowMs);

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
            for (final shift in assignableShiftsAt(nowMs))
              CheckboxListTile(
                dense: true,
                value: _selected.contains(shift),
                activeColor: AppColors.primaryGreen,
                title: Text(shortShiftName(names[shift]!)),
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
