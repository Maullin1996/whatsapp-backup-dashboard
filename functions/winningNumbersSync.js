// Sincronización de los números ganadores (función puente, pieza b2). Lo que
// hace el disparador programado de index.js, sin importar firebase-admin: todas
// las lecturas, la escritura, el logger y la hora llegan por parámetro, así se
// prueba con datos falsos. Ver
// .claude/skills/image-review-firebase-integration.md, "Función puente".
//
// Decidido por el usuario: cada 60 minutos; procesa hoy y ayer en hora de
// Bogotá; si el resultado sale vacío no escribe nada (deja lo que había);
// escribe solo si cambió. `discarded` solo va al log (qué hacer con él sigue
// PENDIENTE).

const { mergeWinningNumbers } = require("./winningNumbers.js");

// Nombre del secreto con la llave de cuenta de servicio de whats-apuestas.
// PROVISIONAL. Nunca se imprime su contenido, solo este nombre.
const WHATS_APUESTAS_SECRET_NAME = "WHATS_APUESTAS_KEY";

// Nombre de la segunda app de Admin (la de whats-apuestas).
const WHATS_APUESTAS_APP_NAME = "whats-apuestas";

const COLLECTIONS = {
  automatic: "resultados_loterias", // whats-apuestas, campo `resultados`
  manual: "manual_lotteries", // whats-apuestas, campo `list`
  winning: "winning_numbers", // este proyecto, campo `numbers`
};

// Bogotá es UTC-5 todo el año (sin horario de verano): se calcula con el
// desfase fijo, sin depender de la zona del servidor.
const BOGOTA_OFFSET_MS = -5 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

const STATUS = {
  written: "escrita",
  unchanged: "sin-cambios",
  skippedEmpty: "omitida-vacia",
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

async function syncDate(dateId, deps) {
  const { readAutomatic, readManual, readStored, writeNumbers, logger } = deps;

  // a. Un documento que no existe llega como null y cuenta como vacío.
  const [automaticDoc, manualDoc] = await Promise.all([
    readAutomatic(dateId),
    readManual(dateId),
  ]);

  // b. La mezcla, sin cambios.
  const { numbers, discarded } = mergeWinningNumbers(
    automaticDoc ?? null,
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
  if (stored && sameNumbers(stored.numbers, numbers)) {
    return STATUS.unchanged;
  }

  // e. Solo el campo `numbers`.
  await writeNumbers(dateId, numbers);
  return STATUS.written;
}

/**
 * Procesa [hoy, ayer] en hora de Bogotá. Nunca lanza por el fallo de una
 * fecha: la registra como `error` (sin escribirla) y sigue con la otra.
 *
 * @param {{
 *   readAutomatic: (dateId: string) => Promise<object|null>,
 *   readManual: (dateId: string) => Promise<object|null>,
 *   readStored: (dateId: string) => Promise<object|null>,
 *   writeNumbers: (dateId: string, numbers: string[]) => Promise<void>,
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
    writeNumbers: (id, numbers) =>
      targetDb.collection(COLLECTIONS.winning).doc(id).set({ numbers }),
  };
}

/**
 * Lo que hace el disparador: lee el secreto, lo parsea como JSON, pide las
 * fuentes a `connect(credentials)` y llama a `syncWinningNumbers`. Si el
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

  return syncWinningNumbers({ ...sources, logger, now });
}

module.exports = {
  syncWinningNumbers,
  runWinningNumbersSync,
  firestoreSources,
  bogotaDateIds,
  STATUS,
  COLLECTIONS,
  WHATS_APUESTAS_SECRET_NAME,
  WHATS_APUESTAS_APP_NAME,
};
