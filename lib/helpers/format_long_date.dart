const _months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/// Fecha en español, sin ceros a la izquierda: `2026-09-26` ->
/// "26 de septiembre de 2026". Solo mira el día, no la hora.
String formatLongDate(DateTime date) =>
    '${date.day} de ${_months[date.month - 1]} de ${date.year}';
