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
      const result = mergeWinningNumbers(
        autoDoc(auto("boyaca", "123"), auto("cauca", "12345")),
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

    test("un elemento nulo cuenta como vacío", () => {
      const result = mergeWinningNumbers(autoDoc(null), [null]);
      assert.deepEqual(result.numbers, []);
      assert.deepEqual(
        result.discarded.map((d) => [d.lottery, d.reason]),
        [
          [null, DISCARD_REASONS.empty],
          [null, DISCARD_REASONS.empty],
        ],
      );
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
