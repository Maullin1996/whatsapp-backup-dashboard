/// Estado de sincronización de un registro con el servidor.
///
/// Todo registro nace [pendiente] y vuelve a [pendiente] cada vez que se
/// re-guarda (habrá que volver a subirlo). Solo la subida (paso posterior)
/// lo marca [sincronizado].
enum EstadoSync { pendiente, sincronizado }
