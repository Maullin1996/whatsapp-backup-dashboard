import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/match_detail_dialog.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';

MatchEntry _match({bool messageEdited = false}) => MatchEntry(
  numero: '4521',
  messageId: 'm1',
  chatJid: 'demo-grupo-norte@g.us',
  groupName: 'Grupo Norte (demo)',
  senderName: 'Ana',
  localTime: '08:15',
  storagePath: 'demo/x/m1.jpg',
  shift: 'Jornada Mañana (06:00 – 10:54)',
  fechaJornada: '2026-09-28',
  messageEdited: messageEdited,
);

Future<void> _openDialog(
  WidgetTester tester, {
  required MatchEntry match,
  bool? realImageEnabledOverride,
  ProviderContainer? container,
}) async {
  final content = MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => MatchDetailDialog(
              match: match,
              realImageEnabled: realImageEnabledOverride ?? false,
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ),
  );
  await tester.pumpWidget(
    container == null
        ? ProviderScope(child: content)
        : UncontrolledProviderScope(container: container, child: content),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra número, senderName, groupName, chatJid, localTime, '
      'jornada y storagePath', (tester) async {
    await _openDialog(tester, match: _match());

    // Cada dato va dentro de una fila "Etiqueta: valor" (`Text.rich`), así
    // que se busca por contenido, no por texto exacto.
    expect(find.textContaining('4521'), findsOneWidget);
    expect(find.textContaining('Ana'), findsOneWidget);
    expect(
      find.textContaining('Grupo Norte (demo) (demo-grupo-norte@g.us)'),
      findsOneWidget,
    );
    expect(find.textContaining('08:15'), findsOneWidget);
    expect(find.textContaining('Mañana'), findsOneWidget);
    expect(find.textContaining('demo/x/m1.jpg'), findsOneWidget);
  });

  group('"Mensaje editado" (Sí/No), NUNCA el texto suelto "Editado"', () {
    testWidgets('mensaje editado: "Mensaje editado: Sí"', (tester) async {
      await _openDialog(tester, match: _match(messageEdited: true));

      expect(find.textContaining('Mensaje editado: Sí'), findsOneWidget);
      // Ningún Text es exactamente "Editado" a secas (ese texto ya existe en
      // el visor con otro significado: si el registro de revisión se
      // volvió a guardar, no si el mensaje de WhatsApp fue editado).
      expect(find.text('Editado'), findsNothing);
    });

    testWidgets('mensaje sin editar: "Mensaje editado: No"', (tester) async {
      await _openDialog(tester, match: _match(messageEdited: false));

      expect(find.textContaining('Mensaje editado: No'), findsOneWidget);
      expect(find.text('Editado'), findsNothing);
    });
  });

  group('imagen bajo demanda', () {
    testWidgets(
      'con el flag apagado, "Ver imagen" muestra el aviso y no crea ningún '
      'ExtendedImage',
      (tester) async {
        await _openDialog(
          tester,
          match: _match(),
          realImageEnabledOverride: false,
        );

        expect(find.text('Ver imagen'), findsOneWidget);
        expect(find.byType(ExtendedImage), findsNothing);

        await tester.tap(find.text('Ver imagen'));
        await tester.pump();

        expect(
          find.text('Imagen no disponible con datos de prueba'),
          findsOneWidget,
        );
        expect(find.byType(ExtendedImage), findsNothing);
      },
    );

    testWidgets(
      'con el flag apagado no lee imageUrlProvider (ni antes ni después de '
      'tocar "Ver imagen")',
      (tester) async {
        var reads = 0;
        final container = ProviderContainer(
          overrides: [
            imageUrlProvider.overrideWith((ref, path) {
              reads++;
              return 'http://localhost/$path';
            }),
          ],
        );
        addTearDown(container.dispose);
        await _openDialog(
          tester,
          match: _match(),
          realImageEnabledOverride: false,
          container: container,
        );

        await tester.tap(find.text('Ver imagen'));
        await tester.pump();

        expect(reads, 0);
      },
    );

    testWidgets(
      'con el flag encendido, el widget de imagen se construye con la URL '
      'de imageUrlProvider (solo construcción, sin esperar carga real: no '
      'se puede probar el estado de carga sin red)',
      (tester) async {
        const fakeUrl = 'http://localhost/demo/x/m1.jpg';
        final container = ProviderContainer(
          overrides: [imageUrlProvider.overrideWith((ref, path) => fakeUrl)],
        );
        addTearDown(container.dispose);
        await _openDialog(
          tester,
          match: _match(),
          realImageEnabledOverride: true,
          container: container,
        );

        await tester.tap(find.text('Ver imagen'));
        // Un solo `pump`, sin `pumpAndSettle`: no se espera a que la carga de
        // red (real o fallida) se resuelva, solo se verifica que el widget
        // se construyó con la URL correcta.
        await tester.pump();

        final image = tester.widget<ExtendedImage>(find.byType(ExtendedImage));
        final provider = image.image as ExtendedNetworkImageProvider;
        expect(provider.url, fakeUrl);
      },
    );
  });
}
