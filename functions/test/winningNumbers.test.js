// Pruebas de mergeWinningNumbers: función pura, sin Admin SDK ni Firebase.
// Se ejecutan con `npm test`.
const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const {
  mergeWinningNumbers,
  lotteryKey,
  DISCARD_REASONS,
} = require("../winningNumbers.js");

/** Un elemento de `resultados_loterias.resultados`. */
function auto(slug, numero, extra = {}) {
  return { nombreLoteria: `Lotería ${slug}`, slug, numero, serie: "045", ...extra };
}

/** Un documento de `manual_lotteries`. */
function manual(slug, result, extra = {}) {
  return {
    lottery: `Lotería ${slug}`,
    slug,
    date: "2026-10-02",
    result,
    series: "999",
    ...extra,
  };
}

function autoDoc(...resultados) {
  return { resultados };
}

describe("mergeWinningNumbers", () => {
  describe("mezcla de fuentes", () => {
    test("la manual reemplaza a la automática de la misma lotería", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("medellin", "1111"), auto("boyaca", "2222")),
        [manual("medellin", "3333")],
      );
      assert.deepEqual(result.numbers, ["2222", "3333"]);
      assert.deepEqual(result.discarded, []);
    });

    test("una lotería que solo está en la manual cuenta como una más", () => {
      const result = mergeWinningNumbers(autoDoc(auto("boyaca", "2222")), [
        manual("huila", "4444"),
      ]);
      assert.deepEqual(result.numbers, ["2222", "4444"]);
    });

    test("solo automática: cuentan todas", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", "2222"), auto("cauca", "5555")),
        [],
      );
      assert.deepEqual(result.numbers, ["2222", "5555"]);
    });

    test("la serie se ignora", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", "2222", { serie: "12" })),
        [manual("cauca", "5555", { series: "abc" })],
      );
      assert.deepEqual(result.numbers, ["2222", "5555"]);
    });

    test("una automática reemplazada no se evalúa (no va a discarded)", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("medellin", 1111)),
        [manual("medellin", "3333")],
      );
      assert.deepEqual(result.numbers, ["3333"]);
      assert.deepEqual(result.discarded, []);
    });

    test("una entrada sin slug no se empareja: cuenta sola", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto(undefined, "1111"), auto("", "2222")),
        [manual(undefined, "3333")],
      );
      assert.deepEqual(result.numbers, ["1111", "2222", "3333"]);
    });
  });

  describe("clave de emparejamiento (PROVISIONAL)", () => {
    test("tildes, mayúsculas y espacios sobrantes no impiden emparejar", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("Bogotá", "1111"), auto("santa  marta", "2222")),
        [manual("  bogota ", "3333"), manual("SANTA MARTA", "4444")],
      );
      assert.deepEqual(result.numbers, ["3333", "4444"]);
    });

    test("lotteryKey: minúsculas, sin tildes, sin espacios sobrantes", () => {
      assert.equal(lotteryKey("  Boyacá  Ñ "), "boyaca n");
      assert.equal(lotteryKey("MEDELLÍN"), "medellin");
    });

    test("lotteryKey: un slug que no es texto da clave vacía", () => {
      assert.equal(lotteryKey(undefined), "");
      assert.equal(lotteryKey(null), "");
      assert.equal(lotteryKey(123), "");
    });
  });

  describe("formato del número", () => {
    test("conserva los ceros a la izquierda", () => {
      const result = mergeWinningNumbers(autoDoc(auto("boyaca", "0123")), [
        manual("cauca", "0007"),
      ]);
      assert.deepEqual(result.numbers, ["0007", "0123"]);
    });

    test("aplica trim al número", () => {
      const result = mergeWinningNumbers(autoDoc(auto("boyaca", " 0123 ")), []);
      assert.deepEqual(result.numbers, ["0123"]);
    });

    test("un valor entero va a discarded, aunque tenga 4 cifras", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", 1234), auto("cauca", 123)),
        [],
      );
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(result.discarded, [
        {
          lottery: "Lotería boyaca",
          source: "automatica",
          value: 1234,
          reason: DISCARD_REASONS.notText,
        },
        {
          lottery: "Lotería cauca",
          source: "automatica",
          value: 123,
          reason: DISCARD_REASONS.notText,
        },
      ]);
    });

    test("un valor de longitud distinta va a discarded", () => {
      // Ajuste b1.1: antes usaba "123", que ahora es válido (3 cifras).
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", "12"), auto("cauca", "12345")),
        [manual("huila", "4444")],
      );
      assert.deepEqual(result.numbers, ["4444"]);
      assert.deepEqual(
        result.discarded.map((d) => [d.lottery, d.reason]),
        [
          ["Lotería boyaca", DISCARD_REASONS.wrongLength],
          ["Lotería cauca", DISCARD_REASONS.wrongLength],
        ],
      );
    });

    test("un valor vacío o ausente va a discarded", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", ""), auto("cauca", "   "), auto("tolima", null)),
        [manual("huila", undefined)],
      );
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(
        result.discarded.map((d) => [d.source, d.reason]),
        [
          ["manual", DISCARD_REASONS.empty],
          ["automatica", DISCARD_REASONS.empty],
          ["automatica", DISCARD_REASONS.empty],
          ["automatica", DISCARD_REASONS.empty],
        ],
      );
    });

    test("un valor con caracteres que no son cifras va a discarded", () => {
      const result = mergeWinningNumbers(autoDoc(auto("boyaca", "12a4")), [
        manual("cauca", "-123"),
      ]);
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(
        result.discarded.map((d) => d.reason),
        [DISCARD_REASONS.notDigits, DISCARD_REASONS.notDigits],
      );
    });

    test("discarded de una manual lleva su lotería y su fuente", () => {
      const result = mergeWinningNumbers(null, [manual("huila", 44)]);
      assert.deepEqual(result.discarded, [
        {
          lottery: "Lotería huila",
          source: "manual",
          value: 44,
          reason: DISCARD_REASONS.notText,
        },
      ]);
    });
  });

  describe("entradas vacías", () => {
    test("sin nada devuelve listas vacías", () => {
      for (const [a, m] of [
        [null, null],
        [undefined, undefined],
        [{}, []],
        [autoDoc(), []],
        [{ resultados: "no es lista" }, "no es lista"],
      ]) {
        assert.deepEqual(mergeWinningNumbers(a, m), {
          numbers: [],
          discarded: [],
        });
      }
    });

    test("solo manual, sin documento automático", () => {
      const result = mergeWinningNumbers(null, [manual("huila", "4444")]);
      assert.deepEqual(result.numbers, ["4444"]);
    });

    test("un elemento nulo va a discarded como sin-loteria", () => {
      // Ajuste b1.1: antes era `vacio`; un elemento nulo no tiene nombre ni
      // slug, y eso ahora se descarta antes de mirar el número.
      const result = mergeWinningNumbers(autoDoc(null), [null]);
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(
        result.discarded.map((d) => [d.lottery, d.reason]),
        [
          [null, DISCARD_REASONS.noLottery],
          [null, DISCARD_REASONS.noLottery],
        ],
      );
    });
  });

  describe("ganadores de 3 cifras (b1.1)", () => {
    test("un ganador de 3 cifras (Cash three) entra a numbers", () => {
      const result = mergeWinningNumbers(
        autoDoc(
          auto("cash_three", "606", { nombreLoteria: "Cash three", serie: null }),
        ),
        [],
      );
      assert.deepEqual(result.numbers, ["606"]);
      assert.deepEqual(result.discarded, []);
    });

    test("uno de 2 o de 5 cifras va a discarded", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", "60"), auto("cauca", "60606")),
        [manual("huila", "07")],
      );
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(
        result.discarded.map((d) => [d.source, d.value, d.reason]),
        [
          ["manual", "07", DISCARD_REASONS.wrongLength],
          ["automatica", "60", DISCARD_REASONS.wrongLength],
          ["automatica", "60606", DISCARD_REASONS.wrongLength],
        ],
      );
    });

    test('"606" y "0606" son valores distintos', () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("cash_three", "606"), auto("boyaca", "0606")),
        [manual("huila", " 606 ")],
      );
      assert.deepEqual(result.numbers, ["0606", "606"]);
    });
  });

  describe("entrada sin lotería (b1.1)", () => {
    test("manual sin nombre ni slug no entra a numbers: sin-loteria", () => {
      const result = mergeWinningNumbers(null, [
        manual("", "0000", { lottery: "" }),
      ]);
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(result.discarded, [
        {
          lottery: null,
          source: "manual",
          value: "0000",
          reason: DISCARD_REASONS.noLottery,
        },
      ]);
    });

    test("solo espacios o ausentes, en cualquiera de las dos fuentes", () => {
      const result = mergeWinningNumbers(
        autoDoc({ nombreLoteria: "  ", slug: " ", numero: "1234", serie: null }),
        [{ date: "2026-10-02", result: "5678", series: "1" }],
      );
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(
        result.discarded.map((d) => [d.source, d.reason]),
        [
          ["manual", DISCARD_REASONS.noLottery],
          ["automatica", DISCARD_REASONS.noLottery],
        ],
      );
    });

    test("con nombre pero sin slug sigue contando sola", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("", "1111", { nombreLoteria: "Boyacá" })),
        [manual(" ", "2222", { lottery: "Boyacá" })],
      );
      assert.deepEqual(result.numbers, ["1111", "2222"]);
      assert.deepEqual(result.discarded, []);
    });
  });

  describe("forma real de un día (datos falsos, b1.1)", () => {
    test("automática con serie texto o null y manual con series", () => {
      const automaticDoc = {
        resultados: [
          { nombreLoteria: "Boyacá", slug: "boyaca", numero: "0457", serie: "123" },
          { nombreLoteria: "Cash three", slug: "cash_three", numero: "606", serie: null },
          { nombreLoteria: "Medellín", slug: "medellin", numero: "8812", serie: "045" },
          { nombreLoteria: "Huila", slug: "huila", numero: "", serie: null },
        ],
      };
      // Lo que el handler pasará: doc.data().list de manual_lotteries/{fecha}.
      const manualDoc = {
        list: [
          { lottery: "Medellín", slug: "medellin", date: "otro formato", result: "9001", series: "77" },
          { lottery: "Sinuano Noche", slug: "sinuano_noche", date: null, result: "3141", series: "" },
          { lottery: "", slug: "", date: "2026-10-02", result: "0000", series: "" },
        ],
      };
      const result = mergeWinningNumbers(automaticDoc, manualDoc.list);
      assert.deepEqual(result.numbers, ["0457", "3141", "606", "9001"]);
      assert.deepEqual(
        result.discarded.map((d) => [d.lottery, d.source, d.reason]),
        [
          [null, "manual", DISCARD_REASONS.noLottery],
          ["Huila", "automatica", DISCARD_REASONS.empty],
        ],
      );
    });

    test("dorado_mañana (automática) y doramaña (manual): un solo valor", () => {
      // Ajuste del alias: antes fijaba que las claves eran distintas; ahora
      // `LOTTERY_KEY_ALIASES` las empareja (misma lotería, 118 fechas).
      assert.equal(lotteryKey("dorado_mañana"), lotteryKey("doramaña"));
      const result = mergeWinningNumbers(
        autoDoc(auto("dorado_mañana", "4821", { nombreLoteria: "Dorado Mañana" })),
        [manual("doramaña", "4821", { lottery: "Dorado Mañana" })],
      );
      assert.deepEqual(result.numbers, ["4821"]);
      assert.deepEqual(result.discarded, []);
    });
  });

  describe("alias doramaña → dorado_mañana", () => {
    test("la manual doramaña reemplaza a la automática Dorado mañana", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("dorado_mañana", "1288", { nombreLoteria: "Dorado Mañana" })),
        [manual("doramaña", "4828", { lottery: "Doramaña" })],
      );
      assert.ok(result.numbers.includes("4828"));
      assert.ok(!result.numbers.includes("1288"));
      assert.deepEqual(result.discarded, []);
    });

    test("con el mismo número en las dos queda uno solo", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("dorado_mañana", "4828")),
        [manual("doramaña", "4828")],
      );
      assert.deepEqual(result.numbers, ["4828"]);
    });

    test("una manual dorado_mañana sigue reemplazando a la automática", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("dorado_mañana", "1288"), auto("boyaca", "2222")),
        [manual("dorado_mañana", "4828")],
      );
      assert.deepEqual(result.numbers, ["2222", "4828"]);
    });

    test("una manual doramaña sin automática de dorado_mañana cuenta como una más", () => {
      const result = mergeWinningNumbers(autoDoc(auto("boyaca", "2222")), [
        manual("doramaña", "4828"),
      ]);
      assert.deepEqual(result.numbers, ["2222", "4828"]);
    });

    test("doradotarde y dorado_tarde no se emparejan", () => {
      assert.notEqual(lotteryKey("doradotarde"), lotteryKey("dorado_tarde"));
      const result = mergeWinningNumbers(
        autoDoc(auto("dorado_tarde", "1111")),
        [manual("doradotarde", "2222")],
      );
      assert.deepEqual(result.numbers, ["1111", "2222"]);
    });

    test("una manual doradotarde sola cuenta como una más", () => {
      const result = mergeWinningNumbers(autoDoc(auto("boyaca", "3333")), [
        manual("doradotarde", "2222"),
      ]);
      assert.deepEqual(result.numbers, ["2222", "3333"]);
    });
  });

  describe("duplicados y orden", () => {
    test("sin duplicados entre fuentes ni dentro de una fuente", () => {
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", "1234"), auto("cauca", "1234"), auto("tolima", " 1234")),
        [manual("huila", "1234"), manual("meta", "1234")],
      );
      assert.deepEqual(result.numbers, ["1234"]);
    });

    test("dos manuales de la misma lotería cuentan las dos", () => {
      const result = mergeWinningNumbers(autoDoc(auto("boyaca", "1111")), [
        manual("boyaca", "2222"),
        manual("Boyacá", "3333"),
      ]);
      assert.deepEqual(result.numbers, ["2222", "3333"]);
    });

    test("orden ascendente, igual sin importar el orden de entrada", () => {
      const a = mergeWinningNumbers(
        autoDoc(auto("boyaca", "9000"), auto("cauca", "0500")),
        [manual("huila", "4321")],
      );
      const b = mergeWinningNumbers(
        autoDoc(auto("cauca", "0500"), auto("boyaca", "9000")),
        [manual("huila", "4321")],
      );
      assert.deepEqual(a.numbers, ["0500", "4321", "9000"]);
      assert.deepEqual(b.numbers, a.numbers);
    });

    test("no modifica las entradas", () => {
      const automatic = autoDoc(auto("boyaca", " 0123 "));
      const manuals = [manual("cauca", "0007")];
      const before = JSON.stringify([automatic, manuals]);
      mergeWinningNumbers(automatic, manuals);
      assert.equal(JSON.stringify([automatic, manuals]), before);
    });
  });
});
