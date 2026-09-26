import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/errors/failure.dart';
import 'package:whatsapp_monitor_viewer/core/time/fecha_jornada.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/repositories/review_uploader.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/pending_upload_indicators.dart';

final _morning = shiftNames[Shift.morning]!;
final _afternoon = shiftNames[Shift.afternoon1]!;
final _today = fechaJornadaDe(DateTime.now().millisecondsSinceEpoch);

ImageReviewRecord _record(
  String id, {
  String? shift,
  String? fecha,
  ReviewRole rol = ReviewRole.revisor,
  EstadoSync estadoSync = EstadoSync.pendiente,
}) => ImageReviewRecord(
  messageId: id,
  chatJid: 'c1',
  shift: shift ?? _morning,
  rol: rol,
  storagePath: 'img_$id.png',
  fechaJornada: fecha ?? _today,
  form: ImageReviewForm(
    comprobantes: [
      Comprobante(
        codigo: 'A1',
        numeros: rol == ReviewRole.revisor ? const ['0123'] : const [],
        total: 1000,
      ),
    ],
  ),
  registradoEn: DateTime(2026, 1, 15, 8),
  registradoPor: 'a@x.com',
  estadoSync: estadoSync,
);

/// Uploader que se detiene en cada registro hasta que el test lo libera.
class _GatedUploader implements ReviewUploader {
  final Map<String, Completer<void>> gates = {};
  final Set<String> failIds;
  final List<String> uploaded = [];

  _GatedUploader({this.failIds = const {}});

  @override
  Future<Either<Failure, Unit>> upload(ImageReviewRecord record) async {
    await gates[record.messageId]?.future;
    if (failIds.contains(record.messageId)) {
      return const Left(Failure.firestore(message: 'sin conexión'));
    }
    uploaded.add(record.messageId);
    return const Right(unit);
  }
}

class _FixedChat extends ActiveChatProvider {
  @override
  Chat? build() =>
      Chat(chatJid: 'c1', groupName: 'g', lastMessageAt: 0, totalImages: 0);
}

void main() {
  late InMemoryImageReviewRepository repo;
  late _GatedUploader uploader;

  Future<void> pumpIndicators(
    WidgetTester tester, {
    ReviewRole rol = ReviewRole.revisor,
    bool withChat = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          imageReviewRepositoryProvider.overrideWithValue(repo),
          reviewUploaderProvider.overrideWithValue(uploader),
          currentReviewRoleProvider.overrideWithValue(rol),
          reviewerUidProvider.overrideWithValue('uid-a'),
          reviewerEmailProvider.overrideWithValue('a@x.com'),
          if (withChat) activeChatProvider.overrideWith(_FixedChat.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Align(child: PendingUploadIndicators())),
        ),
      ),
    );
    await settle(tester);
  }

  setUp(() {
    repo = InMemoryImageReviewRepository();
    uploader = _GatedUploader();
  });

  Finder pill(String text) => find.text(text);

  Future<void> tapPill(WidgetTester tester, String text) async {
    await tester.tap(pill(text));
    await tester.pump(); // abre el diálogo
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> confirm(WidgetTester tester) async {
    await tester.tap(find.text('Subir'));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
  }

  group('visibilidad', () {
    testWidgets('sin pendientes no muestra nada', (tester) async {
      await pumpIndicators(tester);
      expect(find.byType(InkWell), findsNothing);
      expect(find.textContaining('pendiente'), findsNothing);
    });

    testWidgets('con pendientes muestra rol, jornada corta y cantidad', (
      tester,
    ) async {
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      await pumpIndicators(tester);

      expect(pill('Revisor · Mañana · 2 pendientes'), findsOneWidget);
    });

    testWidgets('con un solo registro el texto va en singular', (tester) async {
      await repo.save(_record('a'));
      await pumpIndicators(tester);

      expect(pill('Revisor · Mañana · 1 pendiente'), findsOneWidget);
    });

    testWidgets('el rol sale del rol activo', (tester) async {
      await repo.save(_record('s', rol: ReviewRole.sumador));
      await pumpIndicators(tester, rol: ReviewRole.sumador);

      expect(pill('Sumador · Mañana · 1 pendiente'), findsOneWidget);
    });

    testWidgets('solo sincronizados: no aparece', (tester) async {
      await repo.save(_record('a', estadoSync: EstadoSync.sincronizado));
      await pumpIndicators(tester);

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('sin chat activo no muestra nada', (tester) async {
      await repo.save(_record('a'));
      await pumpIndicators(tester, withChat: false);

      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('una píldora por jornada', (tester) async {
      await repo.save(_record('a'));
      await repo.save(_record('b', shift: _afternoon));
      await repo.save(_record('c', shift: _afternoon));
      await pumpIndicators(tester);

      expect(pill('Revisor · Mañana · 1 pendiente'), findsOneWidget);
      expect(pill('Revisor · Tarde 1 · 2 pendientes'), findsOneWidget);
      expect(find.byType(InkWell), findsNWidgets(2));
    });
  });

  group('fecha', () {
    testWidgets('de hoy no se muestra la fecha', (tester) async {
      await repo.save(_record('a'));
      await pumpIndicators(tester);

      expect(find.textContaining(','), findsNothing);
    });

    testWidgets('de otro día se agrega ", dd/MM/yyyy"', (tester) async {
      await repo.save(_record('a', fecha: '2020-01-05'));
      await pumpIndicators(tester);

      expect(
        pill('Revisor · Mañana, 05/01/2020 · 1 pendiente'),
        findsOneWidget,
      );
    });
  });

  group('subir', () {
    testWidgets('tocar abre el diálogo y Cancelar no sube nada', (
      tester,
    ) async {
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      await pumpIndicators(tester);

      await tapPill(tester, 'Revisor · Mañana · 2 pendientes');

      expect(find.text('Subir 2 registros de Mañana, hoy'), findsOneWidget);
      await tester.tap(find.text('Cancelar'));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      expect(uploader.uploaded, isEmpty);
      expect(pill('Revisor · Mañana · 2 pendientes'), findsOneWidget);
    });

    testWidgets('el diálogo de otro día dice la fecha, no "hoy"', (
      tester,
    ) async {
      await repo.save(_record('a', fecha: '2020-01-05'));
      await pumpIndicators(tester);

      await tapPill(tester, 'Revisor · Mañana, 05/01/2020 · 1 pendiente');

      expect(
        find.text('Subir 1 registro de Mañana, 05/01/2020'),
        findsOneWidget,
      );
    });

    testWidgets('confirmar sube, muestra SnackBar de éxito y la píldora '
        'desaparece', (tester) async {
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      await pumpIndicators(tester);

      await tapPill(tester, 'Revisor · Mañana · 2 pendientes');
      await confirm(tester);

      expect(uploader.uploaded, ['a', 'b']);
      expect(find.text('2 registros subidos'), findsOneWidget);
      expect(find.byType(InkWell), findsNothing);
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, Colors.green);
    });

    testWidgets('con un registro el éxito dice "1 registro subido"', (
      tester,
    ) async {
      await repo.save(_record('a'));
      await pumpIndicators(tester);

      await tapPill(tester, 'Revisor · Mañana · 1 pendiente');
      await confirm(tester);

      expect(find.text('1 registro subido'), findsOneWidget);
    });

    testWidgets('con fallos: SnackBar de advertencia y la píldora sigue con '
        'lo que falta', (tester) async {
      uploader = _GatedUploader(failIds: {'b'});
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      await repo.save(_record('c'));
      await pumpIndicators(tester);

      await tapPill(tester, 'Revisor · Mañana · 3 pendientes');
      await confirm(tester);

      expect(
        find.text('2 subidos, 1 no se pudieron subir; siguen pendientes'),
        findsOneWidget,
      );
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, isNot(Colors.green));
      expect(pill('Revisor · Mañana · 1 pendiente'), findsOneWidget);
    });

    testWidgets('durante la subida muestra "Subiendo X de N" y no se puede '
        'tocar', (tester) async {
      uploader.gates['a'] = Completer<void>();
      uploader.gates['b'] = Completer<void>();
      await repo.save(_record('a'));
      await repo.save(_record('b'));
      await pumpIndicators(tester);

      await tapPill(tester, 'Revisor · Mañana · 2 pendientes');
      await tester.tap(find.text('Subir'));
      await tester.pump(const Duration(milliseconds: 400));
      await settle(tester);

      // Subiendo el primero: 0 hechos de 2.
      expect(pill('Subiendo 0 de 2'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Tocarla mientras sube no abre otro diálogo.
      await tester.tap(pill('Subiendo 0 de 2'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlertDialog), findsNothing);

      // Termina el primero: pasa al segundo.
      uploader.gates['a']!.complete();
      await settle(tester);
      expect(pill('Subiendo 1 de 2'), findsOneWidget);

      uploader.gates['b']!.complete();
      await settle(tester);
      expect(find.textContaining('Subiendo'), findsNothing);
      expect(find.text('2 registros subidos'), findsOneWidget);
    });
  });
}

/// Deja correr las cadenas de futuros (repositorio en memoria, notifier).
/// No usa `pumpAndSettle`: con la subida en curso el indicador de progreso
/// anima sin parar y nunca "se asienta".
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}
