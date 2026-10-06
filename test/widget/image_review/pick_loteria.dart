import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Elige [name] (el nombre para mostrar, p. ej. "Dorado tarde") en el selector
/// de lotería del comprobante [id] del formulario de revisión: abre el menú,
/// lleva la opción a la vista (el menú muestra pocas filas a la vez y desplaza
/// el resto) y la toca. Deja guardado el identificador en el borrador.
///
/// [settle] reemplaza a `pumpAndSettle` en pantallas con animaciones que no
/// terminan (p. ej. el visor de imágenes, que tiene su propio `_settle`).
Future<void> pickLoteria(
  WidgetTester tester,
  int id,
  String name, {
  Future<void> Function(WidgetTester tester)? settle,
}) async {
  Future<void> wait() =>
      settle != null ? settle(tester) : tester.pumpAndSettle();

  await tester.tap(find.byKey(ValueKey('loteria-$id')));
  await wait();
  final item = find.widgetWithText(MenuItemButton, name).last;
  await tester.ensureVisible(item);
  await wait();
  await tester.tap(item);
  await wait();
}
