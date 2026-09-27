// Pruebas de setReviewAssignment con un Admin SDK falso: no usan el emulador ni
// tocan Firebase real. Se ejecutan con `npm test`.
const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const {
  authFake,
  groupQuery,
  db,
  target,
  allUsers,
  reset,
  rejectedWith,
} = require("./helpers/fakeAdmin");

const { setReviewAssignment } = require("../index.js");

const SUPER = { uid: "caller", token: { admin: true, superAdmin: true } };
const CHAT = "120363000000000001@g.us";
const REVISOR = { role: "revisor", chatJid: CHAT, shift: "morning" };
const SUMADOR = { role: "sumador", chatJid: CHAT, shift: "morning" };

function call(data, auth = SUPER) {
  return setReviewAssignment.run({ auth, data, rawRequest: {} });
}

function written() {
  return authFake.setCustomUserClaims.mock.calls.map((c) => c.arguments);
}

/** Un usuario de Auth con sus claims, tal como lo devuelve `listUsers`. */
function authUser(uid, customClaims) {
  return { uid, customClaims };
}

describe("setReviewAssignment", () => {
  beforeEach(() => {
    reset();
    db.groups.add(CHAT);
  });

  describe("quién llama", () => {
    test("sin sesión es rechazado sin leer ni escribir nada", async () => {
      await assert.rejects(
        call({ uid: "u1", assignment: REVISOR }, null),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.getUser.mock.callCount(), 0);
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("un admin que no es superAdmin es rechazado", async () => {
      await assert.rejects(
        call(
          { uid: "u1", assignment: REVISOR },
          { uid: "a", token: { admin: true } },
        ),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.getUser.mock.callCount(), 0);
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });
  });

  describe("validación del payload (antes de tocar Auth)", () => {
    const invalid = [
      ["role inválido", { ...REVISOR, role: "admin" }],
      ["role con otra capitalización", { ...REVISOR, role: "Revisor" }],
      ["role ausente", { chatJid: CHAT, shift: "morning" }],
      ["chatJid vacío", { ...REVISOR, chatJid: "" }],
      ["chatJid solo espacios", { ...REVISOR, chatJid: "   " }],
      ["chatJid que no es texto", { ...REVISOR, chatJid: 123 }],
      ["shift inexistente", { ...REVISOR, shift: "midday" }],
      ["shift con la etiqueta en español", { ...REVISOR, shift: "Jornada Mañana (06:00 – 10:54)" }],
      ["shift 'fuera de jornada' (outOfShift)", { ...REVISOR, shift: "outOfShift" }],
      ["shift ausente", { role: "revisor", chatJid: CHAT }],
      ["assignment que no es objeto", "revisor"],
      ["assignment arreglo", [REVISOR]],
    ];
    for (const [name, assignment] of invalid) {
      test(`rechaza ${name}`, async () => {
        await assert.rejects(
          call({ uid: "u1", assignment }),
          rejectedWith("invalid-argument"),
        );
        assert.equal(authFake.getUser.mock.callCount(), 0);
        assert.equal(authFake.listUsers.mock.callCount(), 0);
        assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
      });
    }

    test("assignment ausente (undefined) no equivale a desactivar", async () => {
      await assert.rejects(
        call({ uid: "u1" }),
        rejectedWith("invalid-argument"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("uid faltante o vacío", async () => {
      await assert.rejects(
        call({ assignment: REVISOR }),
        rejectedWith("invalid-argument"),
      );
      await assert.rejects(
        call({ uid: "", assignment: REVISOR }),
        rejectedWith("invalid-argument"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("cada jornada real es asignable", async () => {
      for (const shift of [
        "morning",
        "afternoon1",
        "afternoon2",
        "night1",
        "night2",
        "holiday",
      ]) {
        authFake.setCustomUserClaims.mock.resetCalls();
        await call({ uid: "u1", assignment: { ...REVISOR, shift } });
        assert.equal(written()[0][1].reviewAssignment.shift, shift);
      }
    });
  });

  describe("el grupo debe existir en group_stats", () => {
    test("chatJid inexistente => not-found y no escribe", async () => {
      await assert.rejects(
        call({
          uid: "u1",
          assignment: { ...REVISOR, chatJid: "999@g.us" },
        }),
        rejectedWith("not-found"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("se consulta group_stats por el campo chatJid", async () => {
      await call({ uid: "u1", assignment: REVISOR });

      assert.deepEqual(groupQuery.mock.calls[0].arguments, [
        "chatJid",
        "==",
        CHAT,
      ]);
    });

    test("desactivar no exige que el grupo exista", async () => {
      db.groups.clear();
      target({ reviewAssignment: REVISOR });

      await call({ uid: "u1", assignment: null });

      assert.equal(groupQuery.mock.callCount(), 0);
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 1);
    });
  });

  test("usuario inexistente => not-found y no escribe", async () => {
    authFake.getUser.mock.mockImplementation(async () => {
      const error = new Error("no user");
      error.code = "auth/user-not-found";
      throw error;
    });

    await assert.rejects(
      call({ uid: "nadie", assignment: REVISOR }),
      rejectedWith("not-found"),
    );
    assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
  });

  describe("asignar", () => {
    test("escribe { role, chatJid, shift } en reviewAssignment", async () => {
      const result = await call({ uid: "u1", assignment: REVISOR });

      assert.deepEqual(result, { success: true });
      assert.deepEqual(written(), [["u1", { reviewAssignment: REVISOR }]]);
    });

    test("descarta claves extra que mande el cliente", async () => {
      await call({
        uid: "u1",
        assignment: { ...REVISOR, admin: true, extra: "x" },
      });

      assert.deepEqual(written()[0][1], { reviewAssignment: REVISOR });
    });

    test("a un superAdmin SÍ se le puede asignar (a diferencia de setUserRole)", async () => {
      target({ admin: true, superAdmin: true });

      const result = await call({ uid: "boss", assignment: SUMADOR });

      assert.deepEqual(result, { success: true });
      assert.deepEqual(written(), [
        ["boss", { admin: true, superAdmin: true, reviewAssignment: SUMADOR }],
      ]);
    });

    test("el merge conserva admin, superAdmin y cualquier otro claim", async () => {
      target({ admin: true, superAdmin: true, otro: "x" });

      await call({ uid: "u1", assignment: REVISOR });

      assert.deepEqual(written()[0], [
        "u1",
        { admin: true, superAdmin: true, otro: "x", reviewAssignment: REVISOR },
      ]);
    });

    test("reasignar reemplaza la asignación anterior del mismo usuario", async () => {
      target({ admin: true, reviewAssignment: SUMADOR });

      await call({ uid: "u1", assignment: REVISOR });

      assert.deepEqual(written()[0][1], {
        admin: true,
        reviewAssignment: REVISOR,
      });
    });

    test("no modifica el objeto de claims que devolvió Auth", async () => {
      const original = { admin: true, reviewAssignment: SUMADOR };
      target(original);

      await call({ uid: "u1", assignment: REVISOR });
      await call({ uid: "u1", assignment: null });

      assert.deepEqual(original, { admin: true, reviewAssignment: SUMADOR });
    });
  });

  describe("desactivar (assignment null)", () => {
    test("borra reviewAssignment sin tocar el resto de claims", async () => {
      target({ admin: true, superAdmin: true, reviewAssignment: REVISOR });

      await call({ uid: "u1", assignment: null });

      assert.deepEqual(written(), [["u1", { admin: true, superAdmin: true }]]);
      assert.equal("reviewAssignment" in written()[0][1], false);
    });

    test("un usuario sin asignación queda igual (idempotente)", async () => {
      target({ admin: true });

      const result = await call({ uid: "u1", assignment: null });

      assert.deepEqual(result, { success: true });
      assert.deepEqual(written(), [["u1", { admin: true }]]);
    });

    test("no recorre a los demás usuarios", async () => {
      target({ reviewAssignment: REVISOR });

      await call({ uid: "u1", assignment: null });

      assert.equal(authFake.listUsers.mock.callCount(), 0);
    });
  });

  describe("unicidad por (role, chatJid, shift)", () => {
    test("rechaza si otro uid ya tiene el mismo rol + grupo + jornada", async () => {
      allUsers([authUser("otro", { reviewAssignment: REVISOR })]);

      await assert.rejects(
        call({ uid: "u1", assignment: REVISOR }),
        rejectedWith("already-exists"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("Revisor y Sumador SÍ pueden compartir chatJid + shift", async () => {
      allUsers([authUser("revisor-1", { reviewAssignment: REVISOR })]);

      await call({ uid: "sumador-1", assignment: SUMADOR });

      assert.deepEqual(written(), [["sumador-1", { reviewAssignment: SUMADOR }]]);
    });

    test("otra jornada o otro grupo con el mismo rol no chocan", async () => {
      db.groups.add("otro@g.us");
      allUsers([
        authUser("otro", { reviewAssignment: { ...REVISOR, shift: "night1" } }),
        authUser("otro2", {
          reviewAssignment: { ...REVISOR, chatJid: "otro@g.us" },
        }),
      ]);

      await call({ uid: "u1", assignment: REVISOR });

      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 1);
    });

    test("re-asignar al MISMO uid con los mismos valores no choca consigo mismo", async () => {
      target({ reviewAssignment: REVISOR });
      allUsers([authUser("u1", { reviewAssignment: REVISOR })]);

      const result = await call({ uid: "u1", assignment: REVISOR });

      assert.deepEqual(result, { success: true });
      assert.deepEqual(written(), [["u1", { reviewAssignment: REVISOR }]]);
    });

    test("usuarios sin claims o sin asignación no estorban", async () => {
      allUsers([
        authUser("a", undefined),
        authUser("b", { admin: true }),
        authUser("c", { reviewAssignment: null }),
      ]);

      await call({ uid: "u1", assignment: REVISOR });

      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 1);
    });

    test("pide hasta 1000 usuarios (límite heredado de listUsers)", async () => {
      await call({ uid: "u1", assignment: REVISOR });

      assert.deepEqual(authFake.listUsers.mock.calls[0].arguments, [1000]);
    });
  });
});
