// Sincronización de las jornadas del ERP (horarios dinámicos, pieza 1). Copia
// la colección `jornadas` de whats-apuestas a una colección `jornadas` de este
// proyecto, sin importar firebase-admin: las lecturas, la escritura y el
// logger llegan por parámetro, así se prueba con datos falsos. La llama
// runWinningNumbersSync, después de los ganadores, con la misma conexión. Ver
// .claude/skills/image-review-firebase-integration.md, "Réplica de jornadas".
//
// Decidido por el usuario: réplica exacta (mismos ids y campos, tal cual, sin
// convertir nada), sin historial ni fechas de vigencia; escribe solo si
// cambió o no existe, con set completo; nunca borra nada.

// Nombres de las colecciones. El de destino es PROVISIONAL.
const JORNADAS_COLLECTIONS = {
  source: "jornadas", // whats-apuestas
  target: "jornadas", // este proyecto (PROVISIONAL)
};

const JORNADAS_STATUS = {
  written: "escrito",
  unchanged: "sin-cambios",
  invalid: "omitido-invalido",
  error: "error",
};

const LOG_TAG = "[JORNADAS]";

// yyyy-MM-ddTHH:mm:ss.000, sin zona horaria (formato visto en el ERP).
const TIME_PATTERN = /^\d{4}-\d{2}-\d{2}T(\d{2}):(\d{2}):\d{2}\.000$/;

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

/**
 * Motivo por el que un campo de hora no es válido, o null si lo es. Solo se
 * mira que sea texto con el formato del ERP y que la hora y el minuto existan.
 */
function timeProblem(field, value) {
  if (typeof value !== "string") return `${field}-no-es-texto`;
  const match = TIME_PATTERN.exec(value);
  if (!match) return `${field}-formato-invalido`;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return `${field}-hora-invalida`;
  return null;
}

/** Motivo por el que un documento del ERP no se copia, o null si se copia. */
function jornadaProblem(data) {
  if (!data || typeof data !== "object") return "sin-datos";
  return timeProblem("startTime", data.startTime) ?? timeProblem("endTime", data.endTime);
}

/** Igualdad profunda de valores de Firestore (los que traen isEqual, por él). */
function sameValue(a, b) {
  if (a === b) return true;
  if (a === null || b === null || typeof a !== "object" || typeof b !== "object") {
    return false;
  }
  if (typeof a.isEqual === "function") return a.isEqual(b);
  if (Array.isArray(a) !== Array.isArray(b)) return false;
  if (Array.isArray(a)) {
    return a.length === b.length && a.every((v, i) => sameValue(v, b[i]));
  }
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  return (
    keysA.length === keysB.length &&
    keysA.every((k) => Object.prototype.hasOwnProperty.call(b, k) && sameValue(a[k], b[k]))
  );
}

async function syncOne(id, data, deps) {
  const problem = jornadaProblem(data);
  if (problem) {
    deps.logger.warn(`${LOG_TAG} ${id} omitido: no se copia`, { id, reason: problem });
    return JORNADAS_STATUS.invalid;
  }
  const stored = await deps.readStoredJornada(id);
  if (stored && sameValue(stored, data)) return JORNADAS_STATUS.unchanged;
  await deps.writeJornada(id, data);
  return JORNADAS_STATUS.written;
}

/**
 * Copia cada documento de `jornadas` del ERP a nuestra colección. Nunca lanza
 * y nunca borra: un documento inválido o que falla se registra y se sigue con
 * los demás; si el ERP no devuelve documentos, no se escribe nada.
 *
 * @param {{
 *   readSourceJornadas: () => Promise<{id: string, data: object}[]>,
 *   readStoredJornada: (id: string) => Promise<object|null>,
 *   writeJornada: (id: string, data: object) => Promise<void>,
 *   logger: {info: Function, warn: Function, error: Function},
 * }} deps
 * @returns {Promise<{id: string, status: string}[]|null>} un estado por
 *   documento, o null si no se pudo leer el ERP.
 */
async function syncJornadas(deps) {
  const { logger } = deps;
  let docs;
  try {
    docs = await deps.readSourceJornadas();
  } catch (error) {
    logger.error(`${LOG_TAG} no se pudo leer el ERP: no se escribe nada`, {
      errorType: errorType(error),
    });
    return null;
  }
  if (!Array.isArray(docs) || docs.length === 0) {
    logger.warn(`${LOG_TAG} el ERP no devolvió documentos: no se escribe ni se borra nada`);
    return [];
  }

  const summary = [];
  for (const { id, data } of docs) {
    let status;
    try {
      status = await syncOne(id, data, deps);
    } catch (error) {
      logger.error(`${LOG_TAG} ${id} falló: no se escribe`, {
        id,
        errorType: errorType(error),
      });
      status = JORNADAS_STATUS.error;
    }
    summary.push({ id, status });
  }
  logger.info(`${LOG_TAG} resumen`, { summary });
  return summary;
}

/**
 * Las tres operaciones de `syncJornadas` sobre dos instancias de Firestore ya
 * creadas: `sourceDb` (whats-apuestas, solo lectura) y `targetDb` (este
 * proyecto). Solo get() y set() sin merge; nunca delete.
 */
function jornadasFirestoreSources(sourceDb, targetDb) {
  return {
    readSourceJornadas: async () => {
      const snap = await sourceDb.collection(JORNADAS_COLLECTIONS.source).get();
      return snap.docs.map((doc) => ({ id: doc.id, data: doc.data() }));
    },
    readStoredJornada: async (id) => {
      const snap = await targetDb.collection(JORNADAS_COLLECTIONS.target).doc(id).get();
      return snap.exists ? snap.data() : null;
    },
    writeJornada: (id, data) =>
      targetDb.collection(JORNADAS_COLLECTIONS.target).doc(id).set(data),
  };
}

module.exports = {
  syncJornadas,
  jornadasFirestoreSources,
  JORNADAS_COLLECTIONS,
  JORNADAS_STATUS,
};
