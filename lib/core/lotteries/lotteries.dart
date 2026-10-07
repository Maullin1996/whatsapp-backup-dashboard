/// Lista CERRADA de loterías del selector del formulario de revisión y de la
/// comparación con los ganadores (`findMatches`). DECIDIDA por el usuario: 43
/// identificadores, cada uno con su nombre para mostrar.
///
/// El identificador es la clave normalizada que usa la función puente
/// (`lotteryKey` de `functions/winningNumbers.js`, con sus alias): es lo que se
/// guarda en `Comprobante.loteria` y lo que trae cada entrada de
/// `winning_numbers/{fecha}.entries`. El nombre solo se usa para mostrar.
/// Vive como constante, en este único archivo; no se lee de Firestore.
const List<({String id, String name})> lotteries = [
  (id: 'medellin', name: 'Medellín'),
  (id: 'santander', name: 'Santander'),
  (id: 'risaralda', name: 'Risaralda'),
  (id: 'dorado_manana', name: 'Dorado mañana'),
  (id: 'dorado_tarde', name: 'Dorado tarde'),
  (id: 'dorado_noche', name: 'Dorado noche'),
  (id: 'culona', name: 'Culona'),
  (id: 'culona_noche', name: 'Culona noche'),
  (id: 'astro_sol', name: 'Astro sol'),
  (id: 'astro_luna', name: 'Astro luna'),
  (id: 'pijao_de_oro', name: 'Pijao de oro'),
  (id: 'paisita_dia', name: 'Paisita día'),
  (id: 'paisita_noche', name: 'Paisita noche'),
  (id: 'chontico_dia', name: 'Chontico día'),
  (id: 'chontico_noche', name: 'Chontico noche'),
  (id: 'cafeterito_tarde', name: 'Cafeterito tarde'),
  (id: 'cafeterito_noche', name: 'Cafeterito noche'),
  (id: 'sinuano_dia', name: 'Sinuano día'),
  (id: 'sinuano_noche', name: 'Sinuano noche'),
  (id: 'cash_three_dia', name: 'Cash three día'),
  (id: 'cash_three_noche', name: 'Cash three noche'),
  (id: 'play_four_dia', name: 'Play four día'),
  (id: 'play_four_noche', name: 'Play four noche'),
  (id: 'saman_dia', name: 'Saman día'),
  (id: 'caribena_dia', name: 'Caribeña día'),
  (id: 'caribena_noche', name: 'Caribeña noche'),
  (id: 'motilon_tarde', name: 'Motilón tarde'),
  (id: 'motilon_noche', name: 'Motilón noche'),
  (id: 'fantastica_dia', name: 'Fantástica día'),
  (id: 'fantastica_noche', name: 'Fantástica noche'),
  (id: 'antioquenita_dia', name: 'Antioqueñita día'),
  (id: 'antioquenita_tarde', name: 'Antioqueñita tarde'),
  (id: 'meta', name: 'Meta'),
  (id: 'valle', name: 'Valle'),
  (id: 'manizales', name: 'Manizales'),
  (id: 'bogota', name: 'Bogotá'),
  (id: 'huila', name: 'Huila'),
  (id: 'cruz_roja', name: 'Cruz Roja'),
  (id: 'cundinamarca', name: 'Cundinamarca'),
  (id: 'cauca', name: 'Cauca'),
  (id: 'tolima', name: 'Tolima'),
  (id: 'boyaca', name: 'Boyacá'),
  (id: 'quindio', name: 'Quindío'),
];

final Map<String, String> _namesById = {
  for (final lottery in lotteries) lottery.id: lottery.name,
};

/// true si [id] es un identificador de la lista (sin normalizar nada: una
/// mayúscula o un espacio de más lo dejan fuera).
bool isKnownLoteria(String? id) => id != null && _namesById.containsKey(id);

/// Nombre para mostrar del identificador [id]; si no está en la lista (por
/// ejemplo, el texto libre de un registro viejo), devuelve el mismo texto.
String loteriaDisplayName(String id) => _namesById[id] ?? id;
