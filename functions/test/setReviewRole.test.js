// Pruebas de setReviewRole con un Admin SDK falso: no usan el emulador ni
// tocan Firebase real. Se ejecutan con `npm test`.
const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const {
  authFake,
  docSet,
  docRef,
  target,
  reset,
  rejectedWith,
} = require("./helpers/fakeAdmin");

const { setReviewRole } = require("../index.js");

const SUPER = { uid: "caller", token: { admin: true, superAdmin: true } };

function call(data, auth = SUPER) {
  return setReviewRole.run({ auth, data, rawRequest: {} });
}

function claimsWritten() {
  return authFake.setCustomUserClaims.mock.calls.map((c) => c.arguments);
}

describe("setReviewRole", () => {
  beforeEach(() => reset());

  describe("quién llama", () => {
    test("sin sesión es rechazado sin leer ni escribir nada", async () => {
      await assert.rejects(
        call({ uid: "u1", role: "revisor" }, null),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.getUser.mock.callCount(), 0);
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("un admin que no es superAdmin es rechazado", async () => {
      await assert.rejects(
        call(
          { uid: "u1", role: "revisor" },
          { uid: "a", token: { admin: true } },
        ),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.getUser.mock.callCount(), 0);
    });
  });

  describe("argumentos", () => {
    test("role inválido => invalid-argument", async () => {
      await assert.rejects(
        call({ uid: "u1", role: "admin" }),
        rejectedWith("invalid-argument"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("uid faltante o vacío => invalid-argument", async () => {
      await assert.rejects(
        call({ role: "revisor" }),
        rejectedWith("invalid-argument"),
      );
      await assert.rejects(
        call({ uid: "", role: "revisor" }),
        rejectedWith("invalid-argument"),
      );
    });

    test("usuario inexistente => not-found y no escribe", async () => {
      authFake.getUser.mock.mockImplementation(async () => {
        const error = new Error("no user");
        error.code = "auth/user-not-found";
        throw error;
      });

      await assert.rejects(
        call({ uid: "nadie", role: "revisor" }),
        rejectedWith("not-found"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });
  });

  describe("fusiona los claims, no los reemplaza", () => {
    test("conserva admin/superAdmin y cualquier otro claim", async () => {
      target({ admin: true, superAdmin: true, otro: "x" });

      await call({ uid: "u1", role: "revisor" });

      assert.deepEqual(claimsWritten()[0], [
        "u1",
        { admin: true, superAdmin: true, otro: "x", reviewRole: "revisor" },
      ]);
    });

    test("un usuario sin claims recibe solo { reviewRole }", async () => {
      target(undefined);

      await call({ uid: "u1", role: "sumador" });

      assert.deepEqual(claimsWritten()[0], ["u1", { reviewRole: "sumador" }]);
    });

    test("no modifica el objeto de claims que devolvió Auth", async () => {
      const original = { admin: true, reviewRole: "sumador" };
      target(original);

      await call({ uid: "u1", role: "revisor" });

      assert.deepEqual(original, { admin: true, reviewRole: "sumador" });
    });
  });

  test("a un objetivo superAdmin SÍ se le puede asignar rol de revisión "
    + "(a diferencia de setUserRole, intencional)", async () => {
    target({ admin: true, superAdmin: true });

    const result = await call({ uid: "boss", role: "sumador" });

    assert.deepEqual(result, { success: true });
    assert.deepEqual(claimsWritten(), [
      ["boss", { admin: true, superAdmin: true, reviewRole: "sumador" }],
    ]);
  });

  describe("null desactiva", () => {
    test("borra la clave reviewRole sin tocar el resto de claims", async () => {
      target({ admin: true, reviewRole: "revisor" });

      await call({ uid: "u1", role: null });

      assert.deepEqual(claimsWritten(), [["u1", { admin: true }]]);
      assert.equal("reviewRole" in claimsWritten()[0][1], false);
    });

    test("un usuario sin rol previo queda igual (idempotente)", async () => {
      target({ admin: true });

      const result = await call({ uid: "u1", role: null });

      assert.deepEqual(result, { success: true });
      assert.deepEqual(claimsWritten(), [["u1", { admin: true }]]);
    });
  });

  describe("limpieza de reviewShifts al cambiar de rol de verdad", () => {
    test("cambiar de revisor a sumador limpia reviewShifts en Firestore", async () => {
      target({ reviewRole: "revisor" });

      await call({ uid: "u1", role: "sumador" });

      assert.equal(docRef.mock.calls[0].arguments[0], "u1");
      assert.deepEqual(docSet.mock.calls[0].arguments, [
        { reviewShifts: [] },
        { merge: true },
      ]);
    });

    test("activar un rol por primera vez (sin rol previo) también limpia "
      + "(no-op si no había nada, pero no se salta la escritura)", async () => {
      target(undefined);

      await call({ uid: "u1", role: "revisor" });

      assert.equal(docSet.mock.callCount(), 1);
      assert.deepEqual(docSet.mock.calls[0].arguments, [
        { reviewShifts: [] },
        { merge: true },
      ]);
    });

    test("desactivar (role null) también limpia reviewShifts", async () => {
      target({ reviewRole: "revisor" });

      await call({ uid: "u1", role: null });

      assert.equal(docSet.mock.callCount(), 1);
      assert.deepEqual(docSet.mock.calls[0].arguments, [
        { reviewShifts: [] },
        { merge: true },
      ]);
    });

    test("reasignar el MISMO rol NO limpia reviewShifts", async () => {
      target({ reviewRole: "revisor" });

      await call({ uid: "u1", role: "revisor" });

      assert.equal(docSet.mock.callCount(), 0);
    });

    test("reasignar null a quien ya no tenía rol no limpia nada", async () => {
      target({ admin: true });

      await call({ uid: "u1", role: null });

      assert.equal(docSet.mock.callCount(), 0);
    });
  });
});
