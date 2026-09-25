/// Textos cortos de validación inline por campo del formulario.
///
/// NO salen de un `ImageReviewFailure` a propósito: `validateImageReviewForm`
/// es fail-fast (solo informa el PRIMER error) y aquí hay que marcar todos
/// los campos con problema a la vez tras el primer intento fallido de
/// guardar. El mensaje completo del primer error (`ImageReviewFailure`,
/// p. ej. "Comprobante 2: ingresa el código") se muestra aparte, junto al
/// botón "Guardar". Mantienen el mismo vocabulario que esos mensajes.
abstract class ReviewFieldHints {
  const ReviewFieldHints._();

  static const String required = 'Obligatorio';
  static const String numbersRequired = 'Agrega al menos un número';
  static const String totalPositive = 'Debe ser mayor que 0';
}
