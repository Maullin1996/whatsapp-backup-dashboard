import 'package:flutter/widgets.dart';

/// true si el foco actual está en un campo de texto (`EditableText`).
bool isTextFieldFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  if (context == null) return false;
  return context.widget is EditableText ||
      context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// `Action` de un atajo del visor que se desactiva mientras un campo de texto
/// tiene el foco.
///
/// Los atajos del visor están más cerca del foco que los
/// `DefaultTextEditingShortcuts`: sin esto, ←, →, 0, - y = actuarían sobre el
/// visor en vez de escribir o mover el cursor en el campo. Al estar
/// desactivada, `Shortcuts` devuelve `ignored` y el evento llega al campo.
class GuardedAction<T extends Intent> extends Action<T> {
  final Object? Function(T intent) onInvoke;

  GuardedAction({required this.onInvoke});

  @override
  bool isEnabled(T intent) => !isTextFieldFocused();

  @override
  Object? invoke(T intent) => onInvoke(intent);
}
