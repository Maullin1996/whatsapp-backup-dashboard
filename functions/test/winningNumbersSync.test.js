// Pruebas de syncWinningNumbers (pieza b2): dependencias falsas en memoria, sin
// conexión a Firebase (solo se usa la clase Timestamp, la misma que devuelve
// Firestore en `updatedAt`). Usa el mergeWinningNumbers real. Se ejecutan con
// `npm test`.
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const { Timestamp } = require("firebase-admin/firestore");
const {
  syncWinningNumbers,
  runWinningNumbersSync,
  firestoreSources,
  bogotaDateIds,
  nextDateId,
  STATUS,
  COLLECTIONS,
  WHATS_APUESTAS_SECRET_NAME,
} = require("../winningNumbersSync.js");

// 2026-10-02 15:00 en Bogotá → hoy 2026-10-02, ayer 2026-10-01.
const NOW = Date.parse("2026-10-02T20:00:00Z");
const TODAY = "2026-10-02";
const YESTERDAY = "2026-10-01";

/** `updatedAt` como lo devuelve Firestore: un Timestamp. */
const ts = (iso) => Timestamp.fromDate(new Date(iso));

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
 * cualquier lectura de esa fecha. Un documento automático sin `updatedAt` se
 * lee con uno de las 13:30 de Bogotá de su propia fecha (el reemplazo del ERP
 * con las loterías de día).
 */
function fakeDeps({ automatic = {}, manual = {}, stored = {}, fail = {} } = {}) {
  const writes = [];
  const entryWrites = [];
  const store = { ...stored };
  const read = (source) => async (id) => {
    if (fail[id]) throw fail[id];
    return source[id] ?? null;
  };
  const readAutomatic = async (id) => {
    const doc = await read(automatic)(id);
    if (!doc || "updatedAt" in doc) return doc;
    return { ...doc, updatedAt: ts(`${id}T13:30:00-05:00`) };
  };
  return {
    writes,
    entryWrites,
    store,
    logger: fakeLogger(),
    readAutomatic,
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
    // El documento de hoy ya fue reemplazado a las 13:30: ayer no se escribe.
    assert.equal(statusOf(summary, YESTERDAY), STATUS.skippedReplaced);
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
      // Hoy: solo manual. Ayer: la lectura de su automática falla.
      manual: { [TODAY]: { list: [manualEntry("huila", "4444")] } },
      automatic: { [YESTERDAY]: { resultados: [autoEntry("cauca", "5678")] } },
      fail: { [YESTERDAY]: boom },
    });
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes, [{ id: TODAY, numbers: ["4444"] }]);
    assert.deepEqual(summary, [
      { date: TODAY, status: STATUS.written },
      { date: YESTERDAY, status: STATUS.error },
    ]);
    const errorLine = deps.logger.lines.find((l) => l.level === "error");
    assert.deepEqual(errorLine.data, { date: YESTERDAY, errorType: "unavailable" });
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
      { date: YESTERDAY, status: STATUS.skippedReplaced },
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

describe("fuente automática: el resultado completo de T vive en T+1", () => {
  // Resultados reales de resultados_loterias/2026-10-10 a las 06:30 de Bogotá:
  // los 32 del día 2026-10-09 (9 de día y 23 de tarde/noche).
  const FULL_OF_1009 = [
    ["medellín", "0169"], ["santander", "3794"], ["risaralda", "7531"],
    ["dorado_mañana", "6125"], ["dorado_tarde", "0457"], ["dorado_noche", "5570"],
    ["culona", "5910"], ["astro_sol", "8121"], ["astro_luna", "4611"],
    ["pijao_de_oro", "5311"], ["paisita_día", "8988"], ["paisita_noche", "4342"],
    ["chontico_día", "6626"], ["chontico_noche", "7882"], ["cafeterito_tarde", "9014"],
    ["cafeterito_noche", "1617"], ["sinuano_día", "8640"], ["sinuano_noche", "8696"],
    ["cash_three_día", "174"], ["cash_three_noche", "097"], ["play_four_día", "2033"],
    ["play_four_noche", "1197"], ["saman_día", "8871"], ["caribeña_día", "2137"],
    ["caribeña_noche", "4595"], ["motilón_tarde", "7859"], ["motilón_noche", "8818"],
    ["fantástica_día", "0401"], ["fantástica_noche", "9852"], ["antioqueñita_día", "0298"],
    ["antioqueñita_tarde", "2740"], ["culona_noche", "4273"],
  ];
  // resultados_loterias/2026-10-10 después del reemplazo de las 13:30:31.
  const DAY_OF_1010 = [
    ["dorado_mañana", "5429"], ["paisita_día", "2130"], ["chontico_día", "7976"],
    ["cafeterito_tarde", "8181"], ["cash_three_día", "744"], ["play_four_día", "3547"],
    ["saman_día", "0731"], ["fantástica_día", "4294"], ["antioqueñita_día", "8252"],
  ];
  const doc = (pairs, updatedAt) => ({
    resultados: pairs.map(([slug, numero]) => autoEntry(slug, numero)),
    updatedAt: ts(updatedAt),
  });
  const D09 = "2026-10-09";
  const D10 = "2026-10-10";
  const D11 = "2026-10-11";
  const at = (iso) => ({ now: () => Date.parse(iso) });

  test("06:55 del 10-10 (doc 10-10 con 32): 10-09 produce 32 y 10-10 no produce nada", async () => {
    const deps = {
      ...fakeDeps({
        automatic: {
          [D10]: doc(FULL_OF_1009, "2026-10-10T11:30:33Z"),
          // El 10-09 del ERP (las 9 de día) no se usa mientras exista el 10-10.
          [D09]: doc(DAY_OF_1010, "2026-10-09T18:30:53Z"),
        },
      }),
      ...at("2026-10-10T11:55:00Z"),
    };
    const summary = await syncWinningNumbers(deps);
    assert.equal(deps.writes.length, 1);
    assert.equal(deps.writes[0].id, D09);
    assert.equal(deps.writes[0].numbers.length, 32);
    assert.equal(deps.store[D09].entries.length, 32);
    assert.ok(
      deps.store[D09].entries.some(
        (e) => e.loteria === "dorado_manana" && e.numero === "6125"
      )
    );
    assert.equal(statusOf(summary, D09), STATUS.written);
    assert.equal(statusOf(summary, D10), STATUS.skippedEmpty);
    assert.equal(deps.store[D10], undefined);
  });

  test("13:55 del 10-10 (doc 10-10 ya reemplazado con 9): 10-09 no se escribe y 10-10 produce 9", async () => {
    const saved = {
      numbers: ["0169", "3794"],
      entries: [{ loteria: "medellin", numero: "0169" }],
    };
    const deps = {
      ...fakeDeps({
        automatic: { [D10]: doc(DAY_OF_1010, "2026-10-10T18:30:31Z") },
        stored: { [D09]: saved },
      }),
      ...at("2026-10-10T18:55:00Z"),
    };
    const summary = await syncWinningNumbers(deps);
    assert.deepEqual(deps.writes.map((w) => w.id), [D10]);
    assert.equal(deps.writes[0].numbers.length, 9);
    assert.equal(statusOf(summary, D10), STATUS.written);
    assert.equal(statusOf(summary, D09), STATUS.skippedReplaced);
    assert.deepEqual(deps.store[D09], saved);
  });

  test("15:00 con T+1 inexistente: T produce las 9 de día", async () => {
    const deps = {
      ...fakeDeps({ automatic: { [D10]: doc(DAY_OF_1010, "2026-10-10T18:30:31Z") } }),
      ...at("2026-10-10T20:00:00Z"),
    };
    const summary = await syncWinningNumbers(deps);
    assert.equal(statusOf(summary, D10), STATUS.written);
    assert.deepEqual(deps.store[D10].numbers, [
      "0731", "2130", "3547", "4294", "5429", "744", "7976", "8181", "8252",
    ]);
  });

  test("T+1 inexistente y T anterior a las 13:00: T no tiene fuente automática, solo la manual", async () => {
    const deps = {
      ...fakeDeps({
        automatic: { [D10]: doc(FULL_OF_1009, "2026-10-10T11:30:33Z") },
        manual: {
          [D10]: {
            list: [{ lottery: "Doramaña", slug: "doramaña", date: D10, result: "5429", series: "000" }],
          },
        },
      }),
      ...at("2026-10-10T17:20:00Z"),
    };
    await syncWinningNumbers(deps);
    assert.deepEqual(deps.store[D10], {
      numbers: ["5429"],
      entries: [{ loteria: "dorado_manana", numero: "5429" }],
    });
  });

  test("21:00 del 10-10: el doc 10-11 recién creado (20:30) es la fuente de 10-10", async () => {
    const deps = {
      ...fakeDeps({
        automatic: {
          [D10]: doc(DAY_OF_1010, "2026-10-10T18:30:31Z"),
          [D11]: doc(
            [["dorado_mañana", "5429"], ["dorado_noche", "9999"]],
            "2026-10-11T01:30:10Z"
          ),
        },
      }),
      ...at("2026-10-11T02:00:00Z"),
    };
    const summary = await syncWinningNumbers(deps);
    // Hoy es 10-10 (Bogotá): su fuente es el doc 10-11; ayer (10-09) ya no.
    assert.deepEqual(deps.store[D10].numbers, ["5429", "9999"]);
    assert.equal(statusOf(summary, D10), STATUS.written);
    assert.equal(statusOf(summary, D09), STATUS.skippedReplaced);
  });

  test("la manual de T reemplaza a la automática tomada de T+1 (usa manual_lotteries/T)", async () => {
    const deps = {
      ...fakeDeps({
        automatic: { [D10]: doc(FULL_OF_1009, "2026-10-10T11:30:33Z") },
        manual: {
          [D09]: {
            list: [{ lottery: "MEDELLÍN", slug: "medellín", date: D09, result: "9999", series: "238" }],
          },
        },
      }),
      ...at("2026-10-10T11:55:00Z"),
    };
    await syncWinningNumbers(deps);
    assert.ok(deps.store[D09].numbers.includes("9999"));
    assert.ok(!deps.store[D09].numbers.includes("0169"));
    assert.equal(deps.store[D09].numbers.length, 32);
  });

  test("nextDateId: cambio de mes y de año", () => {
    assert.equal(nextDateId("2026-10-09"), "2026-10-10");
    assert.equal(nextDateId("2026-09-30"), "2026-10-01");
    assert.equal(nextDateId("2026-12-31"), "2027-01-01");
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
