/// Desfase de Bogotá respecto a UTC. Fijo: Colombia no tiene horario de
/// verano.
const _bogotaBehindUtc = Duration(hours: 5);

/// Reloj de pared de Bogotá (UTC-5 fijo) para el instante [instant],
/// independiente de la zona horaria del dispositivo.
///
/// Devuelve un `DateTime` marcado como UTC solo para que sus campos (`year`,
/// `hour`, ...) se lean tal cual: es la hora que marca un reloj en Bogotá, no
/// el instante en UTC.
///
/// PROPUESTA pendiente de confirmar (ver `image-review-domain`, pendientes de
/// `shift_image_counts`): la fecha y el fin de una jornada se calculan así y no
/// con `toLocal()`, porque un dispositivo en otra zona construiría un id de
/// contador que no existe. Por ahora solo lo usa `jornadaTerminada`;
/// `fechaJornadaDe` sigue usando `toLocal()`.
DateTime bogotaWallClock(DateTime instant) =>
    instant.toUtc().subtract(_bogotaBehindUtc);
