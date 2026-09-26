import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/image_review_failure.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Valida y normaliza el formulario según el [rol]. Fail-fast: devuelve solo
/// el primer error. Orden: al menos un comprobante; luego, por comprobante,
/// código, números (solo Revisor) y total.
///
/// - **Revisor**: código, al menos un número y total > 0 por comprobante.
/// - **Sumador**: código y total > 0 por comprobante. No anota números: la
///   regla de números no aplica y la lista se normaliza a vacía (se descarta
///   lo que llegue).
///
/// Normalización: código y números con `trim` (los números vacíos se
/// descartan, los ceros a la izquierda se conservan); anotaciones vacías o
/// solo con espacios pasan a null. El código es texto libre: solo es error
/// si queda vacío, sin validar formato ni cambiar mayúsculas o tildes.
Either<ImageReviewFailure, ImageReviewForm> validateImageReviewForm(
  ImageReviewForm form,
  ReviewRole rol,
) {
  if (form.comprobantes.isEmpty) {
    return const Left(ImageReviewFailure.sinComprobantes());
  }

  final normalizados = <Comprobante>[];
  for (var i = 0; i < form.comprobantes.length; i++) {
    final indice = i + 1;
    final c = form.comprobantes[i];

    final codigo = c.codigo.trim();
    if (codigo.isEmpty) return Left(ImageReviewFailure.codigoVacio(indice));

    final List<String> numeros;
    switch (rol) {
      case ReviewRole.revisor:
        numeros = c.numeros
            .map((n) => n.trim())
            .where((n) => n.isNotEmpty)
            .toList();
        if (numeros.isEmpty) {
          return Left(ImageReviewFailure.comprobanteSinNumeros(indice));
        }
      case ReviewRole.sumador:
        numeros = const [];
    }

    if (c.total <= 0) return Left(ImageReviewFailure.totalInvalido(indice));

    normalizados.add(c.copyWith(codigo: codigo, numeros: numeros));
  }

  final anotaciones = form.anotaciones?.trim();
  return Right(
    ImageReviewForm(
      comprobantes: normalizados,
      anotaciones: (anotaciones == null || anotaciones.isEmpty)
          ? null
          : anotaciones,
    ),
  );
}
