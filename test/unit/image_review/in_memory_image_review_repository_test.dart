import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';

ImageReviewRecord _record({
  String messageId = 'm1',
  int total = 9000,
  bool editado = false,
}) => ImageReviewRecord(
  messageId: messageId,
  chatJid: 'chat@g.us',
  shift: 'morning',
  form: ImageReviewForm(
    comprobantes: [
      Comprobante(codigo: 'A1', numeros: const ['0123'], total: total),
    ],
  ),
  registradoEn: DateTime(2026, 1, 1, 8),
  registradoPor: 'revisor@example.com',
  editado: editado,
);

ImageReviewRecord? _unwrap(Either<dynamic, ImageReviewRecord?> e) =>
    e.fold((_) => fail('no se esperaba Left'), (r) => r);

void main() {
  late InMemoryImageReviewRepository repo;

  setUp(() => repo = InMemoryImageReviewRepository());

  test('un registro nuevo tiene editado en false por defecto', () {
    expect(
      ImageReviewRecord(
        messageId: 'x',
        chatJid: 'c',
        shift: 's',
        form: const ImageReviewForm(comprobantes: []),
        registradoEn: DateTime(2026),
        registradoPor: 'a@b.c',
      ).editado,
      isFalse,
    );
  });

  test('leer un id inexistente da Right(null)', () async {
    final result = await repo.getByMessageId('nope');
    expect(result.isRight(), isTrue);
    expect(_unwrap(result), isNull);
  });

  test('guardar y leer', () async {
    final r = _record();
    expect((await repo.save(r)).isRight(), isTrue);
    expect(_unwrap(await repo.getByMessageId('m1')), r);
  });

  test('guardar de nuevo el mismo messageId sobrescribe', () async {
    await repo.save(_record(total: 9000));
    final updated = _record(total: 3000, editado: true);
    await repo.save(updated);

    final read = _unwrap(await repo.getByMessageId('m1'));
    expect(read, updated);
    expect(read!.editado, isTrue);
  });

  test('registros de distintos messageId no se pisan', () async {
    await repo.save(_record(messageId: 'm1', total: 1000));
    await repo.save(_record(messageId: 'm2', total: 2000));

    expect(
      _unwrap(await repo.getByMessageId('m1'))!.form.comprobantes.single.total,
      1000,
    );
    expect(
      _unwrap(await repo.getByMessageId('m2'))!.form.comprobantes.single.total,
      2000,
    );
  });

  test('el repositorio no decide editado: guarda lo que recibe', () async {
    await repo.save(_record(editado: false));
    await repo.save(_record(editado: false));
    expect(_unwrap(await repo.getByMessageId('m1'))!.editado, isFalse);
  });
}
