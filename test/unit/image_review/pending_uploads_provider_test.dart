import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/chats/domain/entities/chat.dart';
import 'package:whatsapp_monitor_viewer/features/chats/presentation/provider/active_chat_provider.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/estado_sync.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/pending_uploads_provider.dart';

final _morning = shiftNames[Shift.morning]!;
final _afternoon = shiftNames[Shift.afternoon1]!;
final _night = shiftNames[Shift.night1]!;

Chat _chat(String jid) =>
    Chat(chatJid: jid, groupName: jid, lastMessageAt: 0, totalImages: 0);

ImageReviewRecord _record(
  String id, {
  String chatJid = 'c1',
  String fecha = '2026-01-15',
  String? shift,
  ReviewRole rol = ReviewRole.revisor,
  EstadoSync estadoSync = EstadoSync.pendiente,
}) => ImageReviewRecord(
  messageId: id,
  chatJid: chatJid,
  shift: shift ?? _morning,
  rol: rol,
  storagePath: 'img_$id.png',
  fechaJornada: fecha,
  form: const ImageReviewForm(
    comprobantes: [
      Comprobante(codigo: 'A1', numeros: ['1'], total: 1000),
    ],
  ),
  registradoEn: DateTime(2026, 1, 15, 8),
  registradoPor: 'a@x.com',
  estadoSync: estadoSync,
);

void main() {
  late InMemoryImageReviewRepository repo;
  late ProviderContainer container;

  ProviderContainer makeContainer({ReviewRole rol = ReviewRole.revisor}) {
    final c = ProviderContainer(
      overrides: [
        imageReviewRepositoryProvider.overrideWithValue(repo),
        currentReviewRoleProvider.overrideWithValue(rol),
        reviewerUidProvider.overrideWithValue('uid-a'),
        reviewerEmailProvider.overrideWithValue('a@x.com'),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<(String, String, int)>> read() async => (await container.read(
    pendingUploadsProvider.future,
  )).map((j) => (j.fechaJornada, j.shift, j.cantidad)).toList();

  setUp(() {
    repo = InMemoryImageReviewRepository();
    container = makeContainer();
  });

  test('sin chat activo la lista es vacía', () async {
    await repo.save(_record('a'));
    expect(await read(), isEmpty);
  });

  test('lista las jornadas del chat activo con su cantidad', () async {
    await repo.save(_record('a'));
    await repo.save(_record('b'));
    await repo.save(_record('c', shift: _afternoon));
    container.read(activeChatProvider.notifier).select(_chat('c1'));

    expect(await read(), [
      ('2026-01-15', _morning, 2),
      ('2026-01-15', _afternoon, 1),
    ]);
  });

  test('no depende de los mensajes cargados: incluye días distintos, el más '
      'reciente primero y las jornadas en su orden', () async {
    await repo.save(_record('a', fecha: '2026-01-10', shift: _night));
    await repo.save(_record('b', fecha: '2026-01-10'));
    await repo.save(_record('c', fecha: '2026-01-14', shift: _afternoon));
    container.read(activeChatProvider.notifier).select(_chat('c1'));

    expect(await read(), [
      ('2026-01-14', _afternoon, 1),
      ('2026-01-10', _morning, 1),
      ('2026-01-10', _night, 1),
    ]);
  });

  test('ignora sincronizados, otro chat y el otro rol', () async {
    await repo.save(_record('a', estadoSync: EstadoSync.sincronizado));
    await repo.save(_record('b', chatJid: 'c2'));
    await repo.save(_record('c', rol: ReviewRole.sumador));
    container.read(activeChatProvider.notifier).select(_chat('c1'));

    expect(await read(), isEmpty);

    container.dispose();
    container = makeContainer(rol: ReviewRole.sumador);
    container.read(activeChatProvider.notifier).select(_chat('c1'));
    expect(await read(), [('2026-01-15', _morning, 1)]);
  });

  test('cambia solo al cambiar el chat activo', () async {
    await repo.save(_record('a'));
    await repo.save(_record('b', chatJid: 'c2', fecha: '2026-01-16'));
    final notifier = container.read(activeChatProvider.notifier);

    notifier.select(_chat('c1'));
    expect(await read(), [('2026-01-15', _morning, 1)]);

    notifier.select(_chat('c2'));
    expect(await read(), [('2026-01-16', _morning, 1)]);

    notifier.clear();
    expect(await read(), isEmpty);
  });

  group('guardar desde el borrador', () {
    const target = ImageReviewTarget(
      messageId: 'm1',
      chatJid: 'c1',
      shift: 'Jornada Mañana',
      storagePath: 'img_m1.png',
      fechaJornada: '2026-01-15',
    );
    const key = (messageId: 'm1', rol: ReviewRole.revisor);

    Future<void> saveValid() async {
      final draft = container.read(reviewDraftProvider(key).notifier);
      draft.setCodigo(0, 'A1');
      draft.setNumeroPendiente(0, '0123');
      draft.setTotal(0, '9000');
      await draft.save(target);
    }

    test('el indicador aparece tras guardar, sin recargar a mano', () async {
      container.read(activeChatProvider.notifier).select(_chat('c1'));
      expect(await read(), isEmpty);

      await saveValid();

      expect(await read(), [('2026-01-15', 'Jornada Mañana', 1)]);
    });

    test('re-guardar cambia registradoEn (base de la guarda contra '
        'ediciones durante una subida)', () async {
      await saveValid();
      final first = (await repo.getByMessageId(
        'm1',
        ReviewRole.revisor,
      )).fold((_) => fail('Left'), (r) => r!);

      // Editar el registro y volver a guardar.
      container.read(reviewDraftProvider(key).notifier).startEditing(first);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await container.read(reviewDraftProvider(key).notifier).save(target);
      final second = (await repo.getByMessageId(
        'm1',
        ReviewRole.revisor,
      )).fold((_) => fail('Left'), (r) => r!);

      expect(second.editado, isTrue);
      expect(second.registradoEn, isNot(first.registradoEn));
      expect(second.registradoEn.isAfter(first.registradoEn), isTrue);
    });
  });
}
