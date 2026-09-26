import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/data/repositories/in_memory_image_review_repository.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_record.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

ImageReviewRecord _record({
  String messageId = 'm1',
  ReviewRole rol = ReviewRole.revisor,
  int total = 9000,
  bool editado = false,
}) => ImageReviewRecord(
  messageId: messageId,
  chatJid: 'chat@g.us',
  shift: 'morning',
  rol: rol,
  form: ImageReviewForm(
    comprobantes: [
      Comprobante(
        codigo: 'A1',
        numeros: rol == ReviewRole.revisor ? const ['0123'] : const [],
        total: total,
      ),
    ],
  ),
  registradoEn: DateTime(2026, 1, 1, 8),
  registradoPor: '${rol.name}@example.com',
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
        rol: ReviewRole.revisor,
        form: const ImageReviewForm(comprobantes: []),
        registradoEn: DateTime(2026),
        registradoPor: 'a@b.c',
      ).editado,
      isFalse,
    );
  });

  test('leer un id inexistente da Right(null)', () async {
    final result = await repo.getByMessageId('nope', ReviewRole.revisor);
    expect(result.isRight(), isTrue);
    expect(_unwrap(result), isNull);
  });

  test('guardar y leer', () async {
    final r = _record();
    expect((await repo.save(r)).isRight(), isTrue);
    expect(_unwrap(await repo.getByMessageId('m1', ReviewRole.revisor)), r);
  });

  test('guardar de nuevo el mismo messageId sobrescribe', () async {
    await repo.save(_record(total: 9000));
    final updated = _record(total: 3000, editado: true);
    await repo.save(updated);

    final read = _unwrap(await repo.getByMessageId('m1', ReviewRole.revisor));
    expect(read, updated);
    expect(read!.editado, isTrue);
  });

  test('registros de distintos messageId no se pisan', () async {
    await repo.save(_record(messageId: 'm1', total: 1000));
    await repo.save(_record(messageId: 'm2', total: 2000));

    expect(
      _unwrap(
        await repo.getByMessageId('m1', ReviewRole.revisor),
      )!.form.comprobantes.single.total,
      1000,
    );
    expect(
      _unwrap(
        await repo.getByMessageId('m2', ReviewRole.revisor),
      )!.form.comprobantes.single.total,
      2000,
    );
  });

  test('el repositorio no decide editado: guarda lo que recibe', () async {
    await repo.save(_record(editado: false));
    await repo.save(_record(editado: false));
    expect(
      _unwrap(await repo.getByMessageId('m1', ReviewRole.revisor))!.editado,
      isFalse,
    );
  });

  group('un registro por imagen y por rol', () {
    test('los dos roles de la misma imagen conviven', () async {
      final revisor = _record(rol: ReviewRole.revisor, total: 9000);
      final sumador = _record(rol: ReviewRole.sumador, total: 9500);
      await repo.save(revisor);
      await repo.save(sumador);

      expect(
        _unwrap(await repo.getByMessageId('m1', ReviewRole.revisor)),
        revisor,
      );
      expect(
        _unwrap(await repo.getByMessageId('m1', ReviewRole.sumador)),
        sumador,
      );
    });

    test('guardar un rol no pisa al otro', () async {
      final revisor = _record(rol: ReviewRole.revisor, total: 9000);
      await repo.save(revisor);

      await repo.save(_record(rol: ReviewRole.sumador, total: 1));
      await repo.save(
        _record(rol: ReviewRole.sumador, total: 2, editado: true),
      );

      expect(
        _unwrap(await repo.getByMessageId('m1', ReviewRole.revisor)),
        revisor,
      );
      final sumador = _unwrap(
        await repo.getByMessageId('m1', ReviewRole.sumador),
      );
      expect(sumador!.form.comprobantes.single.total, 2);
      expect(sumador.editado, isTrue);
    });

    test('leer un rol no devuelve el registro del otro', () async {
      await repo.save(_record(rol: ReviewRole.revisor));
      expect(
        _unwrap(await repo.getByMessageId('m1', ReviewRole.sumador)),
        isNull,
      );

      await repo.save(_record(messageId: 'm2', rol: ReviewRole.sumador));
      expect(
        _unwrap(await repo.getByMessageId('m2', ReviewRole.revisor)),
        isNull,
      );
    });
  });
}
