import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Deja elegir un día. En web abre el `showDatePicker` nativo; en móvil (o
/// cualquier no-web) un bottom sheet con `CalendarDatePicker`. Devuelve el día
/// elegido, o `null` si se cancela o se descarta.
///
/// Solo usa widgets de Flutter. No cierra nada más que su propio diálogo o
/// sheet: quien lo llama decide qué hacer con el resultado.
///
/// [isWeb] solo existe para poder probar la rama web (`kIsWeb` es const).
Future<DateTime?> pickSingleDate(
  BuildContext context, {
  required DateTime initialDate,
  @visibleForTesting bool? isWeb,
}) {
  if (isWeb ?? kIsWeb) return _pickWithDialog(context, initialDate);
  return _pickWithBottomSheet(context, initialDate);
}

Future<DateTime?> _pickWithDialog(BuildContext context, DateTime initialDate) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: DateTime(2020),
    lastDate: DateTime.now(),
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: DialogThemeData(backgroundColor: Colors.white),
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryGreen,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: child!,
      );
    },
  );
}

Future<DateTime?> _pickWithBottomSheet(
  BuildContext context,
  DateTime initialDate,
) {
  DateTime selectedDate = initialDate;
  return showModalBottomSheet<DateTime>(
    context: context,
    // Sin esto el sheet se limita a 9/16 del alto de la pantalla y el
    // calendario más los botones se desbordan (y se recortan) en pantallas
    // de ~800 px de alto o menos.
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.pill)),
    ),
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primaryGreen,
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Colors.black87,
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Seleccionar fecha',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.lg),
              CalendarDatePicker(
                initialDate: selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                onDateChanged: (date) {
                  setState(() => selectedDate = date);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black54,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, selectedDate),
                    child: const Text('Seleccionar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
