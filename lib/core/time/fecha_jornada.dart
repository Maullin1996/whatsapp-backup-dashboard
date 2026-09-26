/// Fecha (`yyyy-MM-dd`, hora local) del día al que pertenece la jornada de un
/// mensaje, derivada de su `messageTimestamp` (epoch en milisegundos).
///
/// Usa la misma conversión que `toDomain` para calcular la jornada
/// (`fromMillisecondsSinceEpoch(...).toLocal()`), así que fecha y jornada
/// siempre coinciden.
///
/// OJO: no es `Message.messageDate`, que a pesar del nombre guarda la hora
/// ("HH:mm").
String fechaJornadaDe(int messageTimestamp) {
  final date = DateTime.fromMillisecondsSinceEpoch(messageTimestamp).toLocal();
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}
