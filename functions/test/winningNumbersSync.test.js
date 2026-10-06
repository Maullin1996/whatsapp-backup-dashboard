// Pruebas de syncWinningNumbers (pieza b2): dependencias falsas en memoria, sin
// Admin SDK ni Firebase. Usa el mergeWinningNumbers real. Se ejecutan con
// `npm test`.
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const {
  syncWinningNumbers,
  runWinningNumbersSync,
  firestoreSources,
  bogotaDateIds,
  STATUS,
  COLLECTIONS,
  WHATS_APUESTAS_SECRET_NAME,
} = require("../winningNumbersSync.js");

// 2026-10-02 12:00 en Bogotá → hoy 2026-10-02, ayer 2026-10-01.
const NOW = Date.parse("2026-10-02T17:00:00Z");
const TODAY = "2026-10-02";
const YESTERDAY = "2026-10-01";

function autoEntry(slug, numero) {
  return { nombreLoteria: `Lotería ${slug}`, slug, numero, serie: null };
}

function manualEntry(slug, result) {
  return { lottery: `Lotería ${slug}`, slug, date: TODAY, result, series: "" };
}

function fakeLogger() {
  const lines = [];
  const log = (level) => (message, data) => lines.push({ level, message, data });
  return { lines, info: log("info"), warn: log("warn"), error: log("error") };
}

/**
 * Dependencias falsas. `automatic`, `manual` y `stored` son mapas fecha →
 * documento (ausente = no existe). `fail` es un mapa fecha → error que lanza
 * cualquier lectura de esa fecha.
 */
function fakeDeps({ automatic = {}, manual = {}, stored = {}, fail = {} } = {}) {
  const writes = [];
  const entryWrites = [];
  const store = { ...stored };
  const read = (source) => async (id) => {
    if (fail[id]) throw fail[id];
    return source[id] ?? null;
  };
  return {
    writes,
    entryWrites,
    store,
    logger: fakeLogger(),
    readAutomatic: read(automatic),
    readManual: read(manual),
    readStored: read(store),
    writeNumbers: async (id, numbers, entries) => {
      writes.push({ id, numbers });
      entryWrites.push({ id, entries });
      store[id] = { numbers, entries };
    },
    now: () => NOW,
  };
}

function statusOf(summary, date) {
  return summary.find((s) => s.date === date).status;
}

describe("syncWinningNumbers", () => {
  test("escribe cuando el documento no existe", async () => {
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "1234")] } },
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, [{ id: TODAY, numbers: ["1234"] }]);
    assert.equal(statusOf(summary, TODAY), STATUS.written);
  });

  test("no escribe cuando numbers y entries guardados son iguales, aunque en otro orden", async () => {
    const deps = fakeDeps({
      automatic: {
        [TODAY]: { resultados: [autoEntry("boyaca", "1234"), autoEntry("cauca", "0606")] },
      },
      stored: {
        [TODAY]: {
          numbers: ["1234", "0606"],
          entries: [
            { loteria: "cauca", numero: "0606" },
            { loteria: "boyaca", numero: "1234" },
          ],
        },
      },
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, []);
    assert.equal(statusOf(summary, TODAY), STATUS.unchanged);
  });

  test("escribe cuando son distintos", async () => {
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "1234")] } },
      stored: { [TODAY]: { numbers: ["9999"] } },
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, [{ id: TODAY, numbers: ["1234"] }]);
    assert.equal(statusOf(summary, TODAY), STATUS.written);
  });

  test("escribe solo numbers (lista de textos) y entries (lotería + número)", async () => {
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("cash_three", "606")] } },
      stored: { [TODAY]: { numbers: ["1"], otro: "x" } },
    });
    await syncWinningNumbers(deps);
    assert.deepEqual(deps.store[TODAY], {
      numbers: ["606"],
      entries: [{ loteria: "cash_three", numero: "606" }],
    });
  });

  test("resultado vacío: no escribe y deja lo que había", async () => {
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "")] } },
      manual: { [TODAY]: { list: [] } },
      stored: { [TODAY]: { numbers: ["1234"] }, [YESTERDAY]: { numbers: ["5678"] } },
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, []);
    assert.deepEqual(deps.store[TODAY], { numbers: ["1234"] });
    assert.deepEqual(deps.store[YESTERDAY], { numbers: ["5678"] });
    assert.equal(statusOf(summary, TODAY), STATUS.skippedEmpty);
    assert.equal(statusOf(summary, YESTERDAY), STATUS.skippedEmpty);
    assert.ok(
      deps.logger.lines.some(
        (l) => l.level === "info" && l.message.includes(TODAY) && l.message.includes("no se escribe")
      )
    );
  });

  test("una fuente ausente cuenta como vacía y no rompe la otra", async () => {
    const deps = fakeDeps({
      // Hoy: solo manual. Ayer: solo automática.
      manual: { [TODAY]: { list: [manualEntry("huila", "4444")] } },
      automatic: { [YESTERDAY]: { resultados: [autoEntry("boyaca", "2222")] } },
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, [
      { id: TODAY, numbers: ["4444"] },
      { id: YESTERDAY, numbers: ["2222"] },
    ]);
    assert.equal(statusOf(summary, TODAY), STATUS.written);
    assert.equal(statusOf(summary, YESTERDAY), STATUS.written);
  });

  test("falla de lectura en una fecha: no la escribe y procesa la otra", async () => {
    const boom = Object.assign(new Error("detalle que no va al log"), {
      code: "unavailable",
    });
    const deps = fakeDeps({
      automatic: {
        [TODAY]: { resultados: [autoEntry("boyaca", "1234")] },
        [YESTERDAY]: { resultados: [autoEntry("cauca", "5678")] },
      },
      fail: { [TODAY]: boom },
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, [{ id: YESTERDAY, numbers: ["5678"] }]);
    assert.deepEqual(summary, [
      { date: TODAY, status: STATUS.error },
      { date: YESTERDAY, status: STATUS.written },
    ]);
    const errorLine = deps.logger.lines.find((l) => l.level === "error");
    assert.deepEqual(errorLine.data, { date: TODAY, errorType: "unavailable" });
    assert.ok(!JSON.stringify(deps.logger.lines).includes("detalle que no va al log"));
  });

  test("falla al leer lo guardado: error, sin escribir", async () => {
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "1234")] } },
    });
    deps.readStored = async () => {
      throw new TypeError("x");
    };
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, []);
    assert.equal(statusOf(summary, TODAY), STATUS.error);
  });

  test("la manual reemplaza a la automática (mergeWinningNumbers real)", async () => {
    const deps = fakeDeps({
      automatic: {
        [TODAY]: { resultados: [autoEntry("medellin", "1111"), autoEntry("boyaca", "2222")] },
      },
      manual: { [TODAY]: { list: [manualEntry("medellin", "3333")] } },
    });
    await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, [{ id: TODAY, numbers: ["2222", "3333"] }]);
  });

  test("discarded se registra y nunca se escribe", async () => {
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "12"), autoEntry("cauca", "1234")] } },
      manual: { [TODAY]: { list: [{ lottery: "", slug: "", date: TODAY, result: "0000" }] } },
    });
    await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, [{ id: TODAY, numbers: ["1234"] }]);
    assert.deepEqual(Object.keys(deps.store[TODAY]), ["numbers", "entries"]);
    // Lo descartado no entra a entries.
    assert.deepEqual(deps.store[TODAY].entries, [{ loteria: "cauca", numero: "1234" }]);
    const discardedLines = deps.logger.lines
      .filter((l) => l.level === "warn")
      .map((l) => l.data);
    assert.deepEqual(discardedLines, [
      { date: TODAY, lottery: null, source: "manual", reason: "sin-loteria" },
      { date: TODAY, lottery: "Lotería boyaca", source: "automatica", reason: "longitud-distinta" },
    ]);
  });

  describe("entries", () => {
    const only = (entries, numbers) => ({ [TODAY]: { numbers, entries } });
    const AUTO = { [TODAY]: { resultados: [autoEntry("boyaca", "1234")] } };

    test("un documento con numbers iguales pero sin entries se reescribe una vez", async () => {
      const deps = fakeDeps({
        automatic: AUTO,
        stored: { [TODAY]: { numbers: ["1234"] } },
      });
      const summary = await syncWinningNumbers(deps);
      assert.equal(statusOf(summary, TODAY), STATUS.written);
      assert.deepEqual(deps.writes, [{ id: TODAY, numbers: ["1234"] }]);
      assert.deepEqual(deps.entryWrites, [
        { id: TODAY, entries: [{ loteria: "boyaca", numero: "1234" }] },
      ]);
      // La segunda corrida ya no escribe.
      const again = await syncWinningNumbers(deps);
      assert.equal(statusOf(again, TODAY), STATUS.unchanged);
      assert.equal(deps.writes.length, 1);
    });

    test("con numbers y entries iguales no escribe", async () => {
      const deps = fakeDeps({
        automatic: AUTO,
        stored: only([{ loteria: "boyaca", numero: "1234" }], ["1234"]),
      });
      const summary = await syncWinningNumbers(deps);
      assert.deepEqual(deps.writes, []);
      assert.equal(statusOf(summary, TODAY), STATUS.unchanged);
    });

    test("mismos numbers con otra lotería: escribe", async () => {
      const deps = fakeDeps({
        automatic: AUTO,
        stored: only([{ loteria: "cauca", numero: "1234" }], ["1234"]),
      });
      const summary = await syncWinningNumbers(deps);
      assert.equal(statusOf(summary, TODAY), STATUS.written);
    });

    test("entries guardado con elementos que no son pareja de textos: escribe", async () => {
      const deps = fakeDeps({
        automatic: AUTO,
        stored: only([{ loteria: "boyaca", numero: 1234 }], ["1234"]),
      });
      const summary = await syncWinningNumbers(deps);
      assert.equal(statusOf(summary, TODAY), STATUS.written);
    });

    test("resultado vacío: no escribe aunque lo guardado no tenga entries", async () => {
      const deps = fakeDeps({
        automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "")] } },
        stored: { [TODAY]: { numbers: ["1234"] } },
      });
      const summary = await syncWinningNumbers(deps);
      assert.deepEqual(deps.writes, []);
      assert.deepEqual(deps.store[TODAY], { numbers: ["1234"] });
      assert.equal(statusOf(summary, TODAY), STATUS.skippedEmpty);
    });

    test("entries se escribe en el mismo set que numbers", async () => {
      const deps = fakeDeps({ automatic: AUTO });
      await syncWinningNumbers(deps);
      assert.equal(deps.writes.length, 1);
      assert.equal(deps.entryWrites.length, 1);
      assert.deepEqual(deps.store[TODAY], {
        numbers: ["1234"],
        entries: [{ loteria: "boyaca", numero: "1234" }],
      });
    });
  });

  test("el resumen por fecha trae el estado correcto y se registra", async () => {
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "1234")] } },
      stored: {},
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(summary, [
      { date: TODAY, status: STATUS.written },
      { date: YESTERDAY, status: STATUS.skippedEmpty },
    ]);
    const last = deps.logger.lines.at(-1);
    assert.equal(last.level, "info");
    assert.deepEqual(last.data, { summary });

    // Segunda corrida sobre lo ya escrito: sin cambios.
    const again = await syncWinningNumbers(deps);
    assert.equal(statusOf(again, TODAY), STATUS.unchanged);
    assert.equal(deps.writes.length, 1);
  });
});

describe("bogotaDateIds (UTC-5 fijo)", () => {
  test("2026-10-02T03:30Z es 2026-10-01 22:30 en Bogotá", () => {
    assert.deepEqual(bogotaDateIds(Date.parse("2026-10-02T03:30:00Z")), [
      "2026-10-01",
      "2026-09-30",
    ]);
  });

  test("2026-10-02T05:00Z es 2026-10-02 00:00 en Bogotá", () => {
    assert.deepEqual(bogotaDateIds(Date.parse("2026-10-02T05:00:00Z")), [
      "2026-10-02",
      "2026-10-01",
    ]);
  });

  test("cambio de mes y de año", () => {
    assert.deepEqual(bogotaDateIds(Date.parse("2027-01-01T04:59:59Z")), [
      "2026-12-31",
      "2026-12-30",
    ]);
  });
});

describe("runWinningNumbersSync (secreto)", () => {
  const SECRET_CONTENT = '{"private_key":"NO-DEBE-SALIR-EN-EL-LOG","project_id":"p"}';

  for (const [name, readSecret] of [
    ["ausente (vacío)", () => ""],
    ["no es JSON", () => "{no es json"],
    ["value() lanza", () => {
      throw new Error("sin secreto");
    }],
  ]) {
    test(`secreto ${name}: registra el error y no escribe nada`, async () => {
      const logger = fakeLogger();
      let connected = false;
      const result = await runWinningNumbersSync({
        readSecret,
        connect: () => {
          connected = true;
          return fakeDeps();
        },
        logger,
        now: () => NOW,
      });
      assert.equal(result, null);
      assert.equal(connected, false);
      assert.equal(logger.lines.length, 1);
      assert.equal(logger.lines[0].level, "error");
      assert.ok(logger.lines[0].message.includes(WHATS_APUESTAS_SECRET_NAME));
    });
  }

  test("connect falla: registra el tipo y no escribe nada", async () => {
    const logger = fakeLogger();
    const result = await runWinningNumbersSync({
      readSecret: () => SECRET_CONTENT,
      connect: () => {
        throw Object.assign(new Error(SECRET_CONTENT), { code: "app/invalid-credential" });
      },
      logger,
      now: () => NOW,
    });
    assert.equal(result, null);
    assert.deepEqual(logger.lines[0].data, { errorType: "app/invalid-credential" });
    assert.ok(!JSON.stringify(logger.lines).includes("NO-DEBE-SALIR-EN-EL-LOG"));
  });

  test("secreto válido: pasa el JSON parseado a connect y sincroniza, sin loguearlo", async () => {
    const logger = fakeLogger();
    const deps = fakeDeps({
      automatic: { [TODAY]: { resultados: [autoEntry("boyaca", "1234")] } },
    });
    let received;
    const summary = await runWinningNumbersSync({
      readSecret: () => SECRET_CONTENT,
      connect: (credentials) => {
        received = credentials;
        return deps;
      },
      logger,
      now: () => NOW,
    });
    assert.deepEqual(received, JSON.parse(SECRET_CONTENT));
    assert.deepEqual(deps.writes, [{ id: TODAY, numbers: ["1234"] }]);
    assert.equal(statusOf(summary, TODAY), STATUS.written);
    assert.ok(!JSON.stringify(logger.lines).includes("NO-DEBE-SALIR-EN-EL-LOG"));
  });
});

describe("firestoreSources", () => {
  function fakeDb(docs) {
    const sets = [];
    return {
      sets,
      collection: (c) => ({
        doc: (id) => ({
          get: async () => {
            const key = `${c}/${id}`;
            return { exists: key in docs, data: () => docs[key] };
          },
          set: async (data, options) => sets.push({ path: `${c}/${id}`, data, options }),
        }),
      }),
    };
  }

  test("lee las colecciones esperadas, ausente → null, y escribe sin merge", async () => {
    const source = fakeDb({
      [`${COLLECTIONS.automatic}/${TODAY}`]: { resultados: [] },
      [`${COLLECTIONS.manual}/${TODAY}`]: { list: [] },
    });
    const target = fakeDb({ [`${COLLECTIONS.winning}/${TODAY}`]: { numbers: ["1"] } });
    const s = firestoreSources(source, target);
    assert.deepEqual(await s.readAutomatic(TODAY), { resultados: [] });
    assert.deepEqual(await s.readManual(TODAY), { list: [] });
    assert.equal(await s.readAutomatic(YESTERDAY), null);
    assert.deepEqual(await s.readStored(TODAY), { numbers: ["1"] });
    await s.writeNumbers(TODAY, ["606"], [{ loteria: "cash_three", numero: "606" }]);
    assert.deepEqual(target.sets, [
      {
        path: `${COLLECTIONS.winning}/${TODAY}`,
        data: { numbers: ["606"], entries: [{ loteria: "cash_three", numero: "606" }] },
        options: undefined,
      },
    ]);
    assert.deepEqual(source.sets, []);
  });
});
