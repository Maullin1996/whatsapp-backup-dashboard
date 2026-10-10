// Pruebas de syncJornadas (horarios dinámicos, pieza 1) y de su aislamiento
// con la sincronización de ganadores dentro de runWinningNumbersSync.
// Dependencias falsas en memoria, sin Admin SDK ni Firebase. Se ejecutan con
// `npm test`.
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const {
  syncJornadas,
  jornadasFirestoreSources,
  JORNADAS_COLLECTIONS,
  JORNADAS_STATUS,
} = require("../jornadasSync.js");
const { runWinningNumbersSync, STATUS } = require("../winningNumbersSync.js");

// Un documento con la forma vista en el ERP: 7 campos, tres en null.
function jornada(name, start, end) {
  return {
    name,
    startTime: start,
    endTime: end,
    pendingApproval: false,
    proposedBy: null,
    proposedStartTime: null,
    proposedEndTime: null,
  };
}

const MANANA = jornada("Mañana", "2026-09-30T05:30:00.000", "2026-09-30T10:51:00.000");
const NOCHE = jornada("Noche", "2026-08-13T15:28:00.000", "2026-08-13T22:15:00.000");
const FESTIVOS = jornada(
  "Domingos y Festivos",
  "2026-02-16T06:00:00.000",
  "2026-02-16T19:15:00.000"
);

function fakeLogger() {
  const lines = [];
  const log = (level) => (message, data) => lines.push({ level, message, data });
  return { lines, info: log("info"), warn: log("warn"), error: log("error") };
}

/**
 * Dependencias falsas. `source` es la lista de documentos del ERP ({id,
 * data}); `stored` es un mapa id → documento guardado; `failRead` y
 * `failWrite` son mapas id → error. `deletes` registra cualquier intento de
 * borrar (nunca debería pasar).
 */
function fakeDeps({ source = [], stored = {}, failRead = {}, failWrite = {} } = {}) {
  const writes = [];
  const deletes = [];
  const store = structuredClone(stored);
  return {
    writes,
    deletes,
    store,
    logger: fakeLogger(),
    readSourceJornadas: async () => structuredClone(source),
    readStoredJornada: async (id) => {
      if (failRead[id]) throw failRead[id];
      return store[id] ?? null;
    },
    writeJornada: async (id, data) => {
      if (failWrite[id]) throw failWrite[id];
      writes.push({ id, data });
      store[id] = data;
    },
    deleteJornada: async (id) => deletes.push(id),
  };
}

function statusOf(summary, id) {
  return summary.find((s) => s.id === id).status;
}

describe("syncJornadas", () => {
  test("escribe cuando el documento no existe", async () => {
    const deps = fakeDeps({ source: [{ id: "manana", data: MANANA }] });
    const summary = await syncJornadas(deps);
    assert.deepEqual(deps.writes, [{ id: "manana", data: MANANA }]);
    assert.deepEqual(summary, [{ id: "manana", status: JORNADAS_STATUS.written }]);
  });

  test("no escribe cuando es igual", async () => {
    const deps = fakeDeps({
      source: [{ id: "manana", data: MANANA }],
      stored: { manana: { ...MANANA } },
    });
    const summary = await syncJornadas(deps);
    assert.deepEqual(deps.writes, []);
    assert.equal(statusOf(summary, "manana"), JORNADAS_STATUS.unchanged);
  });

  test("escribe cuando cambió", async () => {
    const changed = { ...MANANA, endTime: "2026-10-03T10:45:00.000" };
    const deps = fakeDeps({
      source: [{ id: "manana", data: changed }],
      stored: { manana: MANANA },
    });
    const summary = await syncJornadas(deps);
    assert.deepEqual(deps.writes, [{ id: "manana", data: changed }]);
    assert.equal(statusOf(summary, "manana"), JORNADAS_STATUS.written);
  });

  test("escribe cuando cambió solo un null (pendingApproval y proposed*)", async () => {
    const proposed = {
      ...MANANA,
      pendingApproval: true,
      proposedBy: "alguien",
      proposedStartTime: "2026-10-03T05:00:00.000",
    };
    const deps = fakeDeps({
      source: [{ id: "manana", data: proposed }],
      stored: { manana: MANANA },
    });
    await syncJornadas(deps);
    assert.deepEqual(deps.writes, [{ id: "manana", data: proposed }]);
  });

  test("copia los 7 campos tal cual, incluidos los null, con el mismo id", async () => {
    const deps = fakeDeps({ source: [{ id: "festivos", data: FESTIVOS }] });
    await syncJornadas(deps);
    const written = deps.writes[0];
    assert.equal(written.id, "festivos");
    assert.deepEqual(written.data, FESTIVOS);
    assert.deepEqual(Object.keys(written.data).sort(), [
      "endTime",
      "name",
      "pendingApproval",
      "proposedBy",
      "proposedEndTime",
      "proposedStartTime",
      "startTime",
    ]);
    assert.equal(written.data.proposedBy, null);
    assert.equal(written.data.proposedStartTime, null);
    assert.equal(written.data.proposedEndTime, null);
    assert.equal(written.data.pendingApproval, false);
    assert.equal(written.data.startTime, "2026-02-16T06:00:00.000");
  });

  for (const [label, startTime, reason] of [
    ["no es texto", 123, "startTime-no-es-texto"],
    ["null", null, "startTime-no-es-texto"],
    ["formato distinto", "2026-09-30 05:30", "startTime-formato-invalido"],
    ["con zona horaria", "2026-09-30T05:30:00.000Z", "startTime-formato-invalido"],
    ["hora 24", "2026-09-30T24:00:00.000", "startTime-hora-invalida"],
    ["minuto 60", "2026-09-30T05:60:00.000", "startTime-hora-invalida"],
  ]) {
    test(`omite un documento con startTime inválido (${label}) sin tocar el guardado`, async () => {
      const deps = fakeDeps({
        source: [
          { id: "manana", data: { ...MANANA, startTime } },
          { id: "noche", data: NOCHE },
        ],
        stored: { manana: MANANA },
      });
      const summary = await syncJornadas(deps);
      assert.deepEqual(deps.writes, [{ id: "noche", data: NOCHE }]);
      assert.deepEqual(deps.store.manana, MANANA);
      assert.equal(statusOf(summary, "manana"), JORNADAS_STATUS.invalid);
      const warn = deps.logger.lines.find((l) => l.level === "warn");
      assert.deepEqual(warn.data, { id: "manana", reason });
    });
  }

  test("omite un documento con endTime inválido", async () => {
    const deps = fakeDeps({
      source: [{ id: "noche", data: { ...NOCHE, endTime: "22:15" } }],
    });
    const summary = await syncJornadas(deps);
    assert.deepEqual(deps.writes, []);
    assert.equal(statusOf(summary, "noche"), JORNADAS_STATUS.invalid);
    assert.equal(deps.logger.lines[0].data.reason, "endTime-formato-invalido");
  });

  test("cero documentos del ERP: no escribe ni borra", async () => {
    const deps = fakeDeps({ source: [], stored: { manana: MANANA, noche: NOCHE } });
    const summary = await syncJornadas(deps);
    assert.deepEqual(summary, []);
    assert.deepEqual(deps.writes, []);
    assert.deepEqual(deps.deletes, []);
    assert.deepEqual(deps.store, { manana: MANANA, noche: NOCHE });
    assert.ok(deps.logger.lines.some((l) => l.level === "warn"));
  });

  test("un error en un documento no frena a los otros", async () => {
    const boom = Object.assign(new Error("detalle que no va al log"), {
      code: "unavailable",
    });
    const deps = fakeDeps({
      source: [
        { id: "festivos", data: FESTIVOS },
        { id: "manana", data: MANANA },
        { id: "noche", data: NOCHE },
      ],
      failRead: { festivos: boom },
      failWrite: { manana: new TypeError("x") },
    });
    const summary = await syncJornadas(deps);
    assert.deepEqual(summary, [
      { id: "festivos", status: JORNADAS_STATUS.error },
      { id: "manana", status: JORNADAS_STATUS.error },
      { id: "noche", status: JORNADAS_STATUS.written },
    ]);
    assert.deepEqual(deps.writes, [{ id: "noche", data: NOCHE }]);
    const errors = deps.logger.lines.filter((l) => l.level === "error").map((l) => l.data);
    assert.deepEqual(errors, [
      { id: "festivos", errorType: "unavailable" },
      { id: "manana", errorType: "TypeError" },
    ]);
    assert.ok(!JSON.stringify(deps.logger.lines).includes("detalle que no va al log"));
  });

  test("si no se puede leer el ERP no escribe nada y no lanza", async () => {
    const deps = fakeDeps({ stored: { manana: MANANA } });
    deps.readSourceJornadas = async () => {
      throw Object.assign(new Error("x"), { code: "permission-denied" });
    };
    const summary = await syncJornadas(deps);
    assert.equal(summary, null);
    assert.deepEqual(deps.writes, []);
    assert.deepEqual(deps.logger.lines[0].data, { errorType: "permission-denied" });
  });

  test("nunca borra: un documento nuestro que ya no está en el ERP se queda", async () => {
    const deps = fakeDeps({
      source: [{ id: "manana", data: MANANA }],
      stored: { manana: MANANA, viejo: NOCHE },
    });
    await syncJornadas(deps);
    assert.deepEqual(deps.deletes, []);
    assert.deepEqual(deps.store.viejo, NOCHE);
  });

  test("el resumen se registra al final", async () => {
    const deps = fakeDeps({ source: [{ id: "manana", data: MANANA }] });
    const summary = await syncJornadas(deps);
    const last = deps.logger.lines.at(-1);
    assert.equal(last.level, "info");
    assert.deepEqual(last.data, { summary });
  });
});

describe("jornadasFirestoreSources", () => {
  function fakeDb(docs) {
    const sets = [];
    const deletes = [];
    return {
      sets,
      deletes,
      batch: () => {
        throw new Error("no se usan batches");
      },
      collection: (c) => ({
        get: async () => ({
          docs: Object.entries(docs)
            .filter(([key]) => key.startsWith(`${c}/`))
            .map(([key, data]) => ({ id: key.slice(c.length + 1), data: () => data })),
        }),
        doc: (id) => ({
          get: async () => {
            const key = `${c}/${id}`;
            return { exists: key in docs, data: () => docs[key] };
          },
          set: async (data, options) => sets.push({ path: `${c}/${id}`, data, options }),
          update: async () => {
            throw new Error("no se usa update");
          },
          delete: async () => deletes.push(`${c}/${id}`),
        }),
      }),
    };
  }

  test("lee jornadas del ERP, lee la nuestra por id y escribe sin merge; nunca borra", async () => {
    const source = fakeDb({
      [`${JORNADAS_COLLECTIONS.source}/manana`]: MANANA,
      [`${JORNADAS_COLLECTIONS.source}/noche`]: NOCHE,
    });
    const target = fakeDb({ [`${JORNADAS_COLLECTIONS.target}/manana`]: MANANA });
    const s = jornadasFirestoreSources(source, target);

    assert.deepEqual(await s.readSourceJornadas(), [
      { id: "manana", data: MANANA },
      { id: "noche", data: NOCHE },
    ]);
    assert.deepEqual(await s.readStoredJornada("manana"), MANANA);
    assert.equal(await s.readStoredJornada("noche"), null);

    const summary = await syncJornadas({ ...s, logger: fakeLogger() });
    assert.deepEqual(summary, [
      { id: "manana", status: JORNADAS_STATUS.unchanged },
      { id: "noche", status: JORNADAS_STATUS.written },
    ]);
    assert.deepEqual(target.sets, [
      { path: `${JORNADAS_COLLECTIONS.target}/noche`, data: NOCHE, options: undefined },
    ]);
    assert.deepEqual(source.sets, []);
    assert.deepEqual(source.deletes, []);
    assert.deepEqual(target.deletes, []);
  });
});

describe("runWinningNumbersSync: ganadores y jornadas aislados", () => {
  // 2026-10-02 15:00 en Bogotá → hoy 2026-10-02.
  const NOW = Date.parse("2026-10-02T20:00:00Z");
  const TODAY = "2026-10-02";

  function winnersDeps() {
    const writes = [];
    return {
      writes,
      readAutomatic: async (id) =>
        id === TODAY
          ? {
              resultados: [{ nombreLoteria: "Boyacá", slug: "boyaca", numero: "1234" }],
              // Reemplazo de las 13:30 con las loterías de día del propio día.
              updatedAt: { toMillis: () => Date.parse("2026-10-02T18:30:00Z") },
            }
          : null,
      readManual: async () => null,
      readStored: async () => null,
      writeNumbers: async (id, numbers) => writes.push({ id, numbers }),
    };
  }

  function run(sources, now = () => NOW) {
    const logger = fakeLogger();
    const result = runWinningNumbersSync({
      readSecret: () => '{"project_id":"p"}',
      connect: () => sources,
      logger,
      now,
    });
    return { result, logger };
  }

  test("corre ganadores y después jornadas, con la misma conexión", async () => {
    const order = [];
    const winners = winnersDeps();
    const original = winners.writeNumbers;
    winners.writeNumbers = async (...a) => {
      order.push("ganadores");
      return original(...a);
    };
    const jornadas = fakeDeps({ source: [{ id: "manana", data: MANANA }] });
    const originalJ = jornadas.writeJornada;
    jornadas.writeJornada = async (...a) => {
      order.push("jornadas");
      return originalJ(...a);
    };
    const { result } = run({ ...winners, jornadas });
    const summary = await result;
    assert.equal(summary.find((s) => s.date === TODAY).status, STATUS.written);
    assert.deepEqual(jornadas.writes, [{ id: "manana", data: MANANA }]);
    assert.deepEqual(order, ["ganadores", "jornadas"]);
  });

  test("un fallo de jornadas no impide la de ganadores ni lanza", async () => {
    const winners = winnersDeps();
    const jornadas = fakeDeps();
    // Un elemento null hace lanzar a syncJornadas (fuera de su try por
    // documento): lo atrapa el try/catch de runWinningNumbersSync.
    jornadas.readSourceJornadas = async () => [null];
    const { result, logger } = run({ ...winners, jornadas });
    const summary = await result;
    assert.deepEqual(winners.writes, [{ id: TODAY, numbers: ["1234"] }]);
    assert.equal(summary.find((s) => s.date === TODAY).status, STATUS.written);
    const line = logger.lines.find((l) => l.level === "error" && l.message.includes("[JORNADAS]"));
    assert.deepEqual(line.data, { errorType: "TypeError" });
  });

  test("un fallo de ganadores no impide la de jornadas", async () => {
    const winners = winnersDeps();
    const jornadas = fakeDeps({ source: [{ id: "manana", data: MANANA }] });
    const { result, logger } = run({ ...winners, jornadas }, () => {
      throw new Error("reloj roto");
    });
    const summary = await result;
    assert.equal(summary, null);
    assert.deepEqual(winners.writes, []);
    assert.deepEqual(jornadas.writes, [{ id: "manana", data: MANANA }]);
    assert.ok(logger.lines.some((l) => l.level === "error" && l.message.includes("[GANADORES]")));
  });

  test("sin jornadas en la conexión, ganadores sigue igual", async () => {
    const winners = winnersDeps();
    const { result } = run(winners);
    const summary = await result;
    assert.equal(summary.find((s) => s.date === TODAY).status, STATUS.written);
  });
});
