// Mezcla de los números ganadores del día (función puente, pieza b1): función
// PURA, sin Firebase. Recibe lo ya leído de las dos fuentes de whats-apuestas y
// devuelve la lista que se guardará en `winning_numbers/{fecha}.numbers`. No
// lee ni escribe nada: eso es del handler programado (pieza b2, pendiente).
// Ver .claude/skills/image-review-firebase-integration.md, "Función puente".
//
// Forma de las entradas — SUPOSICIÓN (no hay ejemplos en el repo; a confirmar
// con datos reales):
//   automaticDoc: documento de `resultados_loterias`,
//     { resultados: [{ nombreLoteria, slug, numero, serie }] }
//   manualList: documentos de `manual_lotteries`,
//     [{ lottery, slug, date, result, series }]
// El llamador pasa solo las entradas de UNA misma fecha: esta función no mira
// `date` (su formato no se conoce todavía).
//
// Reglas decididas por el usuario:
//   - Si la misma lotería está en las dos fuentes, gana la manual.
//   - Una lotería que solo está en la manual cuenta como un número más.
//   - Solo importa el número; la serie se ignora.

const WINNING_NUMBER_LENGTH = 4;

// Motivos de descarte (lo que no es un texto de 4 cifras).
const DISCARD_REASONS = {
  notText: "no-es-texto",
  empty: "vacio",
  notDigits: "no-son-cifras",
  wrongLength: "longitud-distinta",
};

// Clave para emparejar la misma lotería entre las dos colecciones.
// PROVISIONAL, a confirmar con datos reales: el slug en minúsculas, sin tildes
// y sin espacios sobrantes. Es el ÚNICO lugar que decide si dos entradas son
// la misma lotería; para cambiar el criterio basta con cambiar esta función.
function lotteryKey(slug) {
  if (typeof slug !== "string") return "";
  return slug
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim()
    .replace(/\s+/g, " ");
}

// `null` si el valor es un número ganador válido; si no, el motivo.
function discardReason(value) {
  if (value === null || value === undefined) return DISCARD_REASONS.empty;
  if (typeof value !== "string") return DISCARD_REASONS.notText;
  const trimmed = value.trim();
  if (trimmed === "") return DISCARD_REASONS.empty;
  if (!/^\d+$/.test(trimmed)) return DISCARD_REASONS.notDigits;
  if (trimmed.length !== WINNING_NUMBER_LENGTH) return DISCARD_REASONS.wrongLength;
  return null;
}

// Ambas fuentes llevadas a { key, lottery, value, source }.
function normalizeAutomatic(automaticDoc) {
  const resultados = Array.isArray(automaticDoc?.resultados)
    ? automaticDoc.resultados
    : [];
  return resultados.map((entry) => ({
    key: lotteryKey(entry?.slug),
    lottery: entry?.nombreLoteria ?? entry?.slug ?? null,
    value: entry?.numero,
    source: "automatica",
  }));
}

function normalizeManual(manualList) {
  const list = Array.isArray(manualList) ? manualList : [];
  return list.map((entry) => ({
    key: lotteryKey(entry?.slug),
    lottery: entry?.lottery ?? entry?.slug ?? null,
    value: entry?.result,
    source: "manual",
  }));
}

/**
 * Mezcla los ganadores automáticos y manuales de una fecha.
 *
 * - Por cada clave de lotería (`lotteryKey`) presente en la manual, cuentan
 *   las entradas manuales y se ignoran las automáticas de esa clave.
 * - Una entrada sin clave (slug ausente o vacío) no se puede emparejar:
 *   cuenta sola, con su número.
 * - Solo se evalúan las entradas que cuentan: una automática reemplazada no
 *   aparece ni en `numbers` ni en `discarded`.
 *
 * @returns {{
 *   numbers: string[],
 *   discarded: {lottery: string|null, source: string, value: *, reason: string}[],
 * }}
 *   `numbers`: textos de exactamente 4 cifras (con `trim`, ceros a la
 *   izquierda conservados), sin duplicados, en orden ascendente.
 *   `discarded`: lo que no es un texto de 4 cifras, con la lotería de origen
 *   y el motivo, en el orden de entrada (manuales primero). Qué hacer con
 *   ellos lo decide el llamador.
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
    const reason = discardReason(entry.value);
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
  WINNING_NUMBER_LENGTH,
};
