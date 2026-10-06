// Mezcla de los números ganadores del día (función puente, pieza b1): función
// PURA, sin Firebase. Recibe lo ya leído de las dos fuentes de whats-apuestas y
// devuelve la lista que se guardará en `winning_numbers/{fecha}.numbers`. No
// lee ni escribe nada: eso es del handler programado (pieza b2, pendiente).
// Además de `numbers` devuelve `entries`: la pareja (lotería, número) de cada
// ganador, con la lotería en la clave de `lotteryKey` (con alias).
// Ver .claude/skills/image-review-firebase-integration.md, "Función puente".
//
// Forma de las entradas (vista en datos reales, pieza b1.1):
//   automaticDoc: documento de `resultados_loterias` de la fecha,
//     { resultados: [{ nombreLoteria, slug, numero, serie }] }
//     (`serie` llega como texto o null; se ignora).
//   manualList: el handler pasará `doc.data().list` de
//     `manual_lotteries/{yyyy-MM-dd}` (UN documento por fecha con un campo
//     `list`), cuyos elementos son { lottery, slug, date, result, series }.
//     El campo `date` de cada elemento NO se usa: el id del documento ya es la
//     fecha. `series` se ignora.
//
// Reglas decididas por el usuario:
//   - Si la misma lotería está en las dos fuentes, gana la manual.
//   - Una lotería que solo está en la manual cuenta como un número más.
//   - Solo importa el número; la serie se ignora.
//   - Se aceptan ganadores de 3 o 4 cifras ("Cash three" trae 3) en la misma
//     lista. "606" y "0606" son valores distintos.
//   - Una entrada sin nombre de lotería ni slug no es válida.

const WINNING_NUMBER_LENGTHS = [3, 4];

// Motivos de descarte.
const DISCARD_REASONS = {
  notText: "no-es-texto",
  empty: "vacio",
  notDigits: "no-son-cifras",
  wrongLength: "longitud-distinta",
  noLottery: "sin-loteria",
};

// Alias de lotería: clave normalizada → identificador final de la lista
// cerrada del selector. Se aplica después de normalizar, a las entradas de las
// dos fuentes, y apunta directo al identificador (sin encadenar). Las claves
// van ya normalizadas por `lotteryKey` (minúsculas, sin tildes).
// Respaldo: `doramaña` → `dorado_mañana` tiene 119 fechas de coincidencia por
// número (lectura de solo lectura de whats-apuestas del 2026-10-05); los demás
// alias (`doradotarde`, `doradonoche`, `pija0`, `pijao`, `pijo`) los confirmó
// el usuario SIN prueba por número.
const LOTTERY_KEY_ALIASES = {
  doramana: "dorado_manana",
  doradotarde: "dorado_tarde",
  doradonoche: "dorado_noche",
  pija0: "pijao_de_oro",
  pijao: "pijao_de_oro",
  pijo: "pijao_de_oro",
};

// Clave para emparejar la misma lotería entre las dos colecciones.
// PROVISIONAL: el slug en minúsculas, sin tildes y sin espacios sobrantes, y
// después la tabla `LOTTERY_KEY_ALIASES`. Es el ÚNICO lugar que decide si dos
// entradas son la misma lotería; para cambiar el criterio basta con cambiar
// esta función. Alias respaldado por una lectura de whats-apuestas del
// 2026-10-03: doramaña coincide con dorado_mañana en 118 fechas entre
// 2026-01-19 y 2026-10-03; los demás pares probados aparecieron en una sola
// fecha y no se usan.
function lotteryKey(slug) {
  if (typeof slug !== "string") return "";
  const key = slug
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
  return Object.hasOwn(LOTTERY_KEY_ALIASES, key)
    ? LOTTERY_KEY_ALIASES[key]
    : key;
}

// El texto con `trim`, o "" si no es texto.
function trimmedText(value) {
  return typeof value === "string" ? value.trim() : "";
}

// `null` si el valor es un número ganador válido; si no, el motivo.
function discardReason(value) {
  if (value === null || value === undefined) return DISCARD_REASONS.empty;
  if (typeof value !== "string") return DISCARD_REASONS.notText;
  const trimmed = value.trim();
  if (trimmed === "") return DISCARD_REASONS.empty;
  if (!/^\d+$/.test(trimmed)) return DISCARD_REASONS.notDigits;
  if (!WINNING_NUMBER_LENGTHS.includes(trimmed.length)) {
    return DISCARD_REASONS.wrongLength;
  }
  return null;
}

// Orden de texto por unidades de código, igual que `sort()` por defecto.
function compareText(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

// Una entrada de cualquiera de las dos fuentes llevada a
// { key, lottery, value, source }. `lottery` es el nombre o, si falta, el slug
// (con `trim`); `null` si no hay ninguno de los dos.
function normalizeEntry(name, slug, value, source) {
  return {
    key: lotteryKey(slug),
    lottery: trimmedText(name) || trimmedText(slug) || null,
    value,
    source,
  };
}

function normalizeAutomatic(automaticDoc) {
  const resultados = Array.isArray(automaticDoc?.resultados)
    ? automaticDoc.resultados
    : [];
  return resultados.map((entry) =>
    normalizeEntry(entry?.nombreLoteria, entry?.slug, entry?.numero, "automatica")
  );
}

function normalizeManual(manualList) {
  const list = Array.isArray(manualList) ? manualList : [];
  return list.map((entry) =>
    normalizeEntry(entry?.lottery, entry?.slug, entry?.result, "manual")
  );
}

/**
 * Mezcla los ganadores automáticos y manuales de una fecha.
 *
 * - Por cada clave de lotería (`lotteryKey`) presente en la manual, cuentan
 *   las entradas manuales y se ignoran las automáticas de esa clave.
 * - Una entrada sin clave (slug ausente o vacío) pero con nombre no se puede
 *   emparejar: cuenta sola, con su número.
 * - Una entrada sin nombre NI slug (los dos vacíos tras `trim`, o ausentes) no
 *   es válida: va a `discarded` con `sin-loteria`, sin mirar su número.
 * - Solo se evalúan las entradas que cuentan: una automática reemplazada no
 *   aparece ni en `numbers` ni en `discarded`.
 *
 * @param {object|null|undefined} automaticDoc documento de
 *   `resultados_loterias` de la fecha.
 * @param {object[]|null|undefined} manualList `doc.data().list` de
 *   `manual_lotteries/{yyyy-MM-dd}`.
 * @returns {{
 *   numbers: string[],
 *   entries: {loteria: string, numero: string}[],
 *   discarded: {lottery: string|null, source: string, value: *, reason: string}[],
 * }}
 *   `numbers`: textos de exactamente 3 o 4 cifras (con `trim`, ceros a la
 *   izquierda conservados), sin duplicados, en orden ascendente de texto
 *   (`sort()` por defecto).
 *   `entries`: la pareja (lotería, número) de cada ganador válido; `loteria` es
 *   la clave de emparejamiento (`lotteryKey` con alias, "" si la entrada no
 *   tiene slug); sin duplicados por pareja, ordenada por `loteria` y luego por
 *   `numero`. Un número en dos loterías da dos entradas.
 *   `discarded`: lo que no es válido, con la lotería de origen y el motivo,
 *   en el orden de entrada (manuales primero). Qué hacer con ellos lo decide
 *   el llamador.
 */
function mergeWinningNumbers(automaticDoc, manualList) {
  const manual = normalizeManual(manualList);
  const manualKeys = new Set(manual.map((e) => e.key).filter((k) => k !== ""));
  const automatic = normalizeAutomatic(automaticDoc).filter(
    (e) => e.key === "" || !manualKeys.has(e.key)
  );

  const numbers = new Set();
  const pairs = new Map(); // "loteria\u0000numero" → { loteria, numero }
  const discarded = [];
  for (const entry of [...manual, ...automatic]) {
    const reason =
      entry.lottery === null
        ? DISCARD_REASONS.noLottery
        : discardReason(entry.value);
    if (reason === null) {
      const numero = entry.value.trim();
      numbers.add(numero);
      // Sin slug (clave "") pero con nombre: loteria "".
      pairs.set(`${entry.key}\u0000${numero}`, { loteria: entry.key, numero });
    } else {
      discarded.push({
        lottery: entry.lottery,
        source: entry.source,
        value: entry.value,
        reason,
      });
    }
  }

  const entries = [...pairs.values()].sort(
    (a, b) =>
      compareText(a.loteria, b.loteria) || compareText(a.numero, b.numero)
  );
  return { numbers: [...numbers].sort(), entries, discarded };
}

module.exports = {
  mergeWinningNumbers,
  lotteryKey,
  DISCARD_REASONS,
  WINNING_NUMBER_LENGTHS,
};
