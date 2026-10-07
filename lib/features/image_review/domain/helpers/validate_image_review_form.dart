import 'package:dartz/dartz.dart';
import 'package:whatsapp_monitor_viewer/core/errors/image_review_failure.dart';
import 'package:whatsapp_monitor_viewer/core/lotteries/lotteries.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/comprobante.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/image_review_form.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';

/// Valida y normaliza el formulario según el [rol]. Fail-fast: devuelve solo
/// el primer error. Orden: código de la imagen; al menos un comprobante; luego,
/// por comprobante, números (solo Revisor), total y lotería.
///
/// - **Los dos roles**: código de la imagen (uno por foto, vale para todos
///   sus comprobantes), y por comprobante total > 0 y una lotería de la lista
///   cerrada (`lotteries`; identificador exacto, sin normalizar). El Sumador
///   también la exige: usa el mismo formulario y la misma validación.
/// - **Revisor**: además, al menos un número por comprobante.
/// - **Sumador**: no anota números: la regla de números no aplica y la lista
///   se normaliza a vacía (se descarta lo que llegue).
///
/// Normalización: código y números con `trim` (los números vacíos se
/// descartan, los ceros a la izquierda se conservan); anotaciones con `trim`,
/// y vacías pasan a null (son opcionales: nunca dan error). El código es texto
/// libre: solo es error si falta o queda vacío, sin validar formato ni cambiar
/// mayúsculas o tildes. La lotería de cada comprobante se valida por
/// separado y se guarda tal cual (el identificador).
Either<ImageReviewFailure, ImageReviewForm> validateImageReviewForm(
  ImageReviewForm form,
  ReviewRole rol,
) {
  final codigo = form.codigo?.trim() ?? '';
  if (codigo.isEmpty) return const Left(ImageReviewFailure.codigoVacio());

  if (form.comprobantes.isEmpty) {
    return const Left(ImageReviewFailure.sinComprobantes());
  }

  final normalizados = <Comprobante>[];
  for (var i = 0; i < form.comprobantes.length; i++) {
    final indice = i + 1;
    final c = form.comprobantes[i];

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

    if (!isKnownLoteria(c.loteria)) {
      return Left(ImageReviewFailure.loteriaInvalida(indice));
    }

    normalizados.add(c.copyWith(numeros: numeros));
  }

  return Right(
    ImageReviewForm(
      codigo: codigo,
      comprobantes: normalizados,
      anotaciones: _textoOpcional(form.anotaciones),
    ),
  );
}

/// `trim`; vacío o solo espacios -> null.
String? _textoOpcional(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
