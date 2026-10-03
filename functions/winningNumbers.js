// Mezcla de los números ganadores del día (función puente, pieza b1): función
// PURA, sin Firebase. Recibe lo ya leído de las dos fuentes de whats-apuestas y
// devuelve la lista que se guardará en `winning_numbers/{fecha}.numbers`. No
// lee ni escribe nada: eso es del handler programado (pieza b2, pendiente).
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

// Clave para emparejar la misma lotería entre las dos colecciones.
// PROVISIONAL, a confirmar con datos reales: el slug en minúsculas, sin tildes
// y sin espacios sobrantes. Es el ÚNICO lugar que decide si dos entradas son
// la misma lotería; para cambiar el criterio basta con cambiar esta función.
// Hecho observado en datos reales, SIN resolver (PENDIENTE): la automática trae
// `dorado_mañana` y la manual `doramaña`; son la misma lotería (mismo número en
// 6 de 7 días) pero con esta clave no se emparejan y cuentan por separado.
function lotteryKey(slug) {
  if (typeof slug !== "string") return "";
  return slug
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
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
 *   discarded: {lottery: string|null, source: string, value: *, reason: string}[],
 * }}
 *   `numbers`: textos de exactamente 3 o 4 cifras (con `trim`, ceros a la
 *   izquierda conservados), sin duplicados, en orden ascendente de texto
 *   (`sort()` por defecto).
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
  const discarded = [];
  for (const entry of [...manual, ...automatic]) {
    const reason =
      entry.lottery === null
        ? DISCARD_REASONS.noLottery
        : discardReason(entry.value);
    if (reason === null) {
      numbers.add(entry.value.trim());
    } else {
      discarded.push({
        lottery: entry.lottery,
        source: entry.source,
        value: entry.value,
        reason,
      });
    }
  }

  return { numbers: [...numbers].sort(), discarded };
}

module.exports = {
  mergeWinningNumbers,
  lotteryKey,
  DISCARD_REASONS,
  WINNING_NUMBER_LENGTHS,
};
