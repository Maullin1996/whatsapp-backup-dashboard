// Sincronización de los números ganadores (función puente, pieza b2). Lo que
// hace el disparador programado de index.js, sin importar firebase-admin: todas
// las lecturas, la escritura, el logger y la hora llegan por parámetro, así se
// prueba con datos falsos. Ver
// .claude/skills/image-review-firebase-integration.md, "Función puente".
//
// Decidido por el usuario: cada 60 minutos; procesa hoy y ayer en hora de
// Bogotá; si el resultado sale vacío no escribe nada (deja lo que había);
// escribe solo si cambió. El resultado automático de un día T NO se lee de
// `resultados_loterias/T` sino, mientras exista, de `resultados_loterias/T+1`
// (ver `automaticSourceFor`). `discarded` solo va al log (qué hacer con él sigue
// PENDIENTE). Se escribe `{ numbers, entries }`: `numbers` (lista de textos,
// la forma de siempre) y `entries` (la pareja lotería + número de cada ganador).

const { mergeWinningNumbers } = require("./winningNumbers.js");
const { syncJornadas } = require("./jornadasSync.js");

// Nombre del secreto con la llave de cuenta de servicio de whats-apuestas.
// PROVISIONAL. Nunca se imprime su contenido, solo este nombre.
const WHATS_APUESTAS_SECRET_NAME = "WHATS_APUESTAS_KEY";

// Nombre de la segunda app de Admin (la de whats-apuestas).
const WHATS_APUESTAS_APP_NAME = "whats-apuestas";

const COLLECTIONS = {
  automatic: "resultados_loterias", // whats-apuestas, campo `resultados`
  manual: "manual_lotteries", // whats-apuestas, campo `list`
  winning: "winning_numbers", // este proyecto, campos `numbers` y `entries`
};

// Bogotá es UTC-5 todo el año (sin horario de verano): se calcula con el
// desfase fijo, sin depender de la zona del servidor.
const BOGOTA_OFFSET_MS = -5 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

// Hora de Bogotá (UTC-5 fijo) del día D a partir de la cual el documento
// `resultados_loterias/D` deja de ser el resultado completo del día D-1.
// Hechos observados en el ERP: el documento D se crea a las 20:30 de D-1 y se
// reescribe a las 06:30 de D con TODOS los resultados de D-1 (día, tarde y
// noche); a las 13:30 de D su contenido se REEMPLAZA por las 9 loterías de día
// de D. Las 13:00 quedan entre la escritura de las 06:30 y el reemplazo de las
// 13:30. Se compara contra el `updatedAt` del documento (un Timestamp de
// Firestore dentro de los datos, no el metadato).
const AUTOMATIC_DOC_SWITCH_TIME = "T13:00:00-05:00";

const STATUS = {
  written: "escrita",
  unchanged: "sin-cambios",
  skippedEmpty: "omitida-vacia",
  // El documento T+1 ya fue reemplazado: el resultado completo de T ya no
  // existe en el ERP y se conserva lo guardado.
  skippedReplaced: "omitida-reemplazada",
  error: "error",
};

const LOG_TAG = "[GANADORES]";

/** `yyyy-MM-dd` de un instante (ms) desplazado a UTC-5. */
function bogotaDateId(ms) {
  return new Date(ms + BOGOTA_OFFSET_MS).toISOString().slice(0, 10);
}

/** [hoy, ayer] en hora de Bogotá, como ids `yyyy-MM-dd`. */
function bogotaDateIds(nowMs) {
  return [bogotaDateId(nowMs), bogotaDateId(nowMs - DAY_MS)];
}

/** `yyyy-MM-dd` del día siguiente a un id `yyyy-MM-dd`. */
function nextDateId(dateId) {
  return new Date(Date.parse(`${dateId}T00:00:00Z`) + DAY_MS)
    .toISOString()
    .slice(0, 10);
}

/** Instante (ms) de AUTOMATIC_DOC_SWITCH_TIME del día `dateId`. */
function switchTimeMs(dateId) {
  return Date.parse(`${dateId}${AUTOMATIC_DOC_SWITCH_TIME}`);
}

/** `updatedAt` del documento (Timestamp de Firestore) en ms; NaN si falta. */
function updatedAtMs(doc) {
  const value = doc.updatedAt;
  return value && typeof value.toMillis === "function" ? value.toMillis() : NaN;
}

/**
 * Fuente automática del resultado del día `dateId`:
 *  1. Si `resultados_loterias/(T+1)` existe y su `updatedAt` es anterior a las
 *     13:00 de T+1, ese documento es el resultado completo de T.
 *  2. Si T+1 no existe, la fuente es `resultados_loterias/T` solo si su
 *     `updatedAt` es posterior a las 13:00 de T; si no, T no tiene fuente
 *     automática todavía (`doc: null`).
 *  3. Si T+1 existe con `updatedAt` posterior a las 13:00 de T+1, el resultado
 *     de T ya se perdió: `replaced: true`, no se escribe T.
 * @returns {Promise<{doc: object|null, replaced: boolean}>}
 */
async function automaticSourceFor(dateId, readAutomatic) {
  const nextId = nextDateId(dateId);
  const next = await readAutomatic(nextId);
  if (next) {
    return updatedAtMs(next) < switchTimeMs(nextId)
      ? { doc: next, replaced: false }
      : { doc: null, replaced: true };
  }
  const own = await readAutomatic(dateId);
  const usable = own && updatedAtMs(own) > switchTimeMs(dateId);
  return { doc: usable ? own : null, replaced: false };
}

/** Tipo de un error, para el log (nunca su contenido). */
function errorType(error) {
  if (error && typeof error === "object") {
    if (typeof error.code === "string" || typeof error.code === "number") {
      return String(error.code);
    }
    if (typeof error.name === "string") return error.name;
  }
  return typeof error;
}

/** true si `stored` es una lista de textos igual a `numbers` (ya ordenada). */
function sameNumbers(stored, numbers) {
  if (!Array.isArray(stored) || stored.length !== numbers.length) return false;
  if (!stored.every((n) => typeof n === "string")) return false;
  const sorted = [...stored].sort();
  return sorted.every((n, i) => n === numbers[i]);
}

/**
 * true si `stored` es una lista de `{loteria, numero}` (textos) con las mismas
 * parejas que `entries`, en cualquier orden. Un documento sin `entries` (el de
 * antes de este campo) nunca es igual.
 */
function sameEntries(stored, entries) {
  if (!Array.isArray(stored) || stored.length !== entries.length) return false;
  const isPair = (e) =>
    e !== null &&
    typeof e === "object" &&
    typeof e.loteria === "string" &&
    typeof e.numero === "string";
  if (!stored.every(isPair)) return false;
  const key = (e) => `${e.loteria}\u0000${e.numero}`;
  const sorted = stored.map(key).sort();
  return sorted.every((k, i) => k === key(entries[i]));
}

async function syncDate(dateId, deps) {
  const { readAutomatic, readManual, readStored, writeNumbers, logger } = deps;

  // a. Un documento que no existe llega como null y cuenta como vacío. La
  // manual sigue siendo `manual_lotteries/{dateId}` (su campo `date` es el día).
  const [automatic, manualDoc] = await Promise.all([
    automaticSourceFor(dateId, readAutomatic),
    readManual(dateId),
  ]);

  // El documento T+1 ya fue reemplazado: no se escribe T, queda lo guardado.
  if (automatic.replaced) {
    logger.info(`${LOG_TAG} ${dateId} su resultado completo ya fue reemplazado: no se escribe`);
    return STATUS.skippedReplaced;
  }

  // b. La mezcla, sin cambios.
  const { numbers, entries, discarded } = mergeWinningNumbers(
    automatic.doc,
    manualDoc?.list ?? null
  );

  // f. discarded: solo al log.
  for (const d of discarded) {
    logger.warn(`${LOG_TAG} descartado`, {
      date: dateId,
      lottery: d.lottery,
      source: d.source,
      reason: d.reason,
    });
  }

  // c. Vacío: no se escribe, queda lo que había.
  if (numbers.length === 0) {
    logger.info(`${LOG_TAG} ${dateId} sin ganadores: no se escribe`);
    return STATUS.skippedEmpty;
  }

  // d. Solo si cambió (o si no existe el documento).
  const stored = await readStored(dateId);
  if (
    stored &&
    sameNumbers(stored.numbers, numbers) &&
    sameEntries(stored.entries, entries)
  ) {
    return STATUS.unchanged;
  }

  // e. `numbers` y `entries`, en el mismo set.
  await writeNumbers(dateId, numbers, entries);
  return STATUS.written;
}

/**
 * Procesa [hoy, ayer] en hora de Bogotá. Nunca lanza por el fallo de una
 * fecha: la registra como `error` (sin escribirla) y sigue con la otra.
 *
 * @param {{
 *   readAutomatic: (dateId: string) => Promise<object|null>, // doc de
 *     `resultados_loterias/{dateId}` con su `updatedAt` (Timestamp)
 *   readManual: (dateId: string) => Promise<object|null>,
 *   readStored: (dateId: string) => Promise<object|null>,
 *   writeNumbers: (dateId: string, numbers: string[],
 *     entries: {loteria: string, numero: string}[]) => Promise<void>,
 *   logger: {info: Function, warn: Function, error: Function},
 *   now: () => number,
 * }} deps
 * @returns {Promise<{date: string, status: string}[]>} un estado por fecha.
 */
async function syncWinningNumbers(deps) {
  const { logger, now } = deps;
  const summary = [];
  for (const dateId of bogotaDateIds(now())) {
    let status;
    try {
      status = await syncDate(dateId, deps);
    } catch (error) {
      logger.error(`${LOG_TAG} ${dateId} falló: no se escribe`, {
        date: dateId,
        errorType: errorType(error),
      });
      status = STATUS.error;
    }
    summary.push({ date: dateId, status });
  }
  logger.info(`${LOG_TAG} resumen`, { summary });
  return summary;
}

/**
 * Las cuatro operaciones de `syncWinningNumbers` sobre dos instancias de
 * Firestore ya creadas: `sourceDb` (whats-apuestas, solo lectura) y
 * `targetDb` (este proyecto, `winning_numbers`). Un documento ausente → null.
 */
function firestoreSources(sourceDb, targetDb) {
  const read = async (db, collection, id) => {
    const snap = await db.collection(collection).doc(id).get();
    return snap.exists ? snap.data() : null;
  };
  return {
    readAutomatic: (id) => read(sourceDb, COLLECTIONS.automatic, id),
    readManual: (id) => read(sourceDb, COLLECTIONS.manual, id),
    readStored: (id) => read(targetDb, COLLECTIONS.winning, id),
    writeNumbers: (id, numbers, entries) =>
      targetDb.collection(COLLECTIONS.winning).doc(id).set({ numbers, entries }),
  };
}

/**
 * Lo que hace el disparador: lee el secreto, lo parsea como JSON, pide las
 * fuentes a `connect(credentials)` y llama a `syncWinningNumbers` y, después,
 * a `syncJornadas` si `connect` devolvió `jornadas` (jornadasSync.js). Si el
 * secreto falta, no se puede parsear o `connect` falla, registra el error (sin
 * su contenido) y termina sin escribir nada.
 *
 * @param {{
 *   readSecret: () => string,
 *   connect: (credentials: object) => object,
 *   logger: {info: Function, warn: Function, error: Function},
 *   now: () => number,
 * }} deps
 * @returns {Promise<{date: string, status: string}[]|null>} null si no corrió.
 */
async function runWinningNumbersSync({ readSecret, connect, logger, now }) {
  let credentials;
  try {
    const raw = readSecret();
    credentials = typeof raw === "string" && raw.trim() !== "" ? JSON.parse(raw) : null;
  } catch (_) {
    credentials = null;
  }
  if (!credentials || typeof credentials !== "object") {
    logger.error(
      `${LOG_TAG} el secreto ${WHATS_APUESTAS_SECRET_NAME} falta o no es JSON válido: no se escribe nada`
    );
    return null;
  }

  let sources;
  try {
    sources = connect(credentials);
  } catch (error) {
    logger.error(
      `${LOG_TAG} no se pudo conectar con ${WHATS_APUESTAS_APP_NAME}: no se escribe nada`,
      { errorType: errorType(error) }
    );
    return null;
  }

  // Ganadores y jornadas, aislados: cada uno en su try/catch, ninguno lanza
  // al otro. Jornadas usa la misma conexión (`sources.jornadas`).
  let summary = null;
  try {
    summary = await syncWinningNumbers({ ...sources, logger, now });
  } catch (error) {
    logger.error(`${LOG_TAG} la sincronización falló`, { errorType: errorType(error) });
  }
  if (sources.jornadas) {
    try {
      await syncJornadas({ ...sources.jornadas, logger });
    } catch (error) {
      logger.error("[JORNADAS] la sincronización falló", { errorType: errorType(error) });
    }
  }
  return summary;
}

module.exports = {
  syncWinningNumbers,
  runWinningNumbersSync,
  firestoreSources,
  bogotaDateIds,
  nextDateId,
  STATUS,
  COLLECTIONS,
  WHATS_APUESTAS_SECRET_NAME,
  WHATS_APUESTAS_APP_NAME,
};
