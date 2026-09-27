// Pruebas de updateReviewShifts con un Admin SDK falso: no usan el emulador
// ni tocan Firebase real. Se ejecutan con `npm test`.
const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const {
  authFake,
  docSet,
  docRef,
  db,
  target,
  allUsers,
  reset,
  rejectedWith,
} = require("./helpers/fakeAdmin");

const { updateReviewShifts } = require("../index.js");

const SUPER = { uid: "caller", token: { admin: true, superAdmin: true } };
const CHAT = "120363000000000001@g.us";
const CHAT2 = "120363000000000002@g.us";

function call(data, auth = SUPER) {
  return updateReviewShifts.run({ auth, data, rawRequest: {} });
}

/** Un usuario de Auth con sus claims, tal como lo devuelve `listUsers`. */
function authUser(uid, customClaims) {
  return { uid, customClaims };
}

function written() {
  return docSet.mock.calls.map((c) => c.arguments);
}

describe("updateReviewShifts", () => {
  beforeEach(() => {
    reset();
    db.groups.add(CHAT);
    db.groups.add(CHAT2);
  });

  describe("quién llama", () => {
    test("sin sesión es rechazado sin leer ni escribir nada", async () => {
      await assert.rejects(
        call({ uid: "u1", shifts: [] }, null),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.getUser.mock.callCount(), 0);
      assert.equal(docSet.mock.callCount(), 0);
    });

    test("un admin que no es superAdmin es rechazado", async () => {
      await assert.rejects(
        call({ uid: "u1", shifts: [] }, { uid: "a", token: { admin: true } }),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.getUser.mock.callCount(), 0);
    });
  });

  describe("validación del payload (antes de tocar Auth)", () => {
    test("shifts no es un array => invalid-argument", async () => {
      await assert.rejects(
        call({ uid: "u1", shifts: "nope" }),
        rejectedWith("invalid-argument"),
      );
      assert.equal(authFake.getUser.mock.callCount(), 0);
    });

    test("entrada sin chatJid => invalid-argument", async () => {
      await assert.rejects(
        call({ uid: "u1", shifts: [{ shift: "morning" }] }),
        rejectedWith("invalid-argument"),
      );
    });

    test("shift inexistente => invalid-argument", async () => {
      await assert.rejects(
        call({ uid: "u1", shifts: [{ chatJid: CHAT, shift: "midday" }] }),
        rejectedWith("invalid-argument"),
      );
    });

    test("shift 'outOfShift' => invalid-argument (no es asignable)", async () => {
      await assert.rejects(
        call({ uid: "u1", shifts: [{ chatJid: CHAT, shift: "outOfShift" }] }),
        rejectedWith("invalid-argument"),
      );
    });

    test("uid faltante => invalid-argument", async () => {
      await assert.rejects(
        call({ shifts: [] }),
        rejectedWith("invalid-argument"),
      );
    });
  });

  test("usuario inexistente => not-found y no escribe", async () => {
    authFake.getUser.mock.mockImplementation(async () => {
      const error = new Error("no user");
      error.code = "auth/user-not-found";
      throw error;
    });

    await assert.rejects(
      call({ uid: "nadie", shifts: [] }),
      rejectedWith("not-found"),
    );
    assert.equal(docSet.mock.callCount(), 0);
  });

  test("rechaza sin reviewRole asignado (failed-precondition) y no escribe", async () => {
    target({ admin: true }); // sin reviewRole

    await assert.rejects(
      call({ uid: "u1", shifts: [{ chatJid: CHAT, shift: "morning" }] }),
      rejectedWith("failed-precondition"),
    );
    assert.equal(docSet.mock.callCount(), 0);
  });

  describe("el grupo debe existir en group_stats", () => {
    beforeEach(() => target({ reviewRole: "revisor" }));

    test("chatJid inexistente => not-found y no escribe", async () => {
      await assert.rejects(
        call({
          uid: "u1",
          shifts: [{ chatJid: "999@g.us", shift: "morning" }],
        }),
        rejectedWith("not-found"),
      );
      assert.equal(docSet.mock.callCount(), 0);
    });
  });

  describe("unicidad por (reviewRole, chatJid, shift)", () => {
    beforeEach(() => target({ reviewRole: "revisor" }));

    test("rechaza si otro del MISMO rol ya cubre ese grupo+jornada", async () => {
      allUsers([authUser("otro", { reviewRole: "revisor" })]);
      db.userDocs.otro = { reviewShifts: [{ chatJid: CHAT, shift: "morning" }] };

      await assert.rejects(
        call({ uid: "u1", shifts: [{ chatJid: CHAT, shift: "morning" }] }),
        rejectedWith("already-exists"),
      );
      assert.equal(docSet.mock.callCount(), 0);
    });

    test("el error lista TODAS las tuplas en conflicto, no solo la primera", async () => {
      allUsers([authUser("otro", { reviewRole: "revisor" })]);
      db.userDocs.otro = {
        reviewShifts: [
          { chatJid: CHAT, shift: "morning" },
          { chatJid: CHAT2, shift: "night1" },
        ],
      };

      await assert.rejects(
        call({
          uid: "u1",
          shifts: [
            { chatJid: CHAT, shift: "morning" },
            { chatJid: CHAT2, shift: "night1" },
            { chatJid: CHAT2, shift: "holiday" }, // libre, no debe listarse
          ],
        }),
        (error) => {
          assert.equal(error.code, "already-exists");
          assert.deepEqual(error.details, {
            conflicts: [
              { chatJid: CHAT, shift: "morning" },
              { chatJid: CHAT2, shift: "night1" },
            ],
          });
          return true;
        },
      );
      assert.equal(docSet.mock.callCount(), 0);
    });

    test("Revisor y Sumador SÍ pueden compartir chatJid + shift", async () => {
      allUsers([authUser("sumador-1", { reviewRole: "sumador" })]);
      db.userDocs["sumador-1"] = {
        reviewShifts: [{ chatJid: CHAT, shift: "morning" }],
      };

      const result = await call({
        uid: "u1",
        shifts: [{ chatJid: CHAT, shift: "morning" }],
      });

      assert.deepEqual(result, { success: true });
    });

    test("reasignarse a sí mismo lo mismo no choca consigo mismo", async () => {
      allUsers([authUser("u1", { reviewRole: "revisor" })]);
      db.userDocs.u1 = { reviewShifts: [{ chatJid: CHAT, shift: "morning" }] };

      const result = await call({
        uid: "u1",
        shifts: [{ chatJid: CHAT, shift: "morning" }],
      });

      assert.deepEqual(result, { success: true });
    });

    test("usuarios sin reviewRole o sin documento en Firestore no estorban", async () => {
      allUsers([
        authUser("a", undefined),
        authUser("b", { admin: true }),
        authUser("c", { reviewRole: "revisor" }), // sin doc en Firestore
      ]);

      const result = await call({
        uid: "u1",
        shifts: [{ chatJid: CHAT, shift: "morning" }],
      });

      assert.deepEqual(result, { success: true });
    });
  });

  describe("reemplazo completo (como updateUserGroups)", () => {
    test("escribe exactamente la lista nueva, no combina con la anterior", async () => {
      target({ reviewRole: "revisor" });
      db.userDocs.u1 = { reviewShifts: [{ chatJid: CHAT2, shift: "night1" }] };

      await call({ uid: "u1", shifts: [{ chatJid: CHAT, shift: "morning" }] });

      assert.equal(docRef.mock.calls[0].arguments[0], "u1");
      assert.deepEqual(written(), [
        [
          { reviewShifts: [{ chatJid: CHAT, shift: "morning" }] },
          { merge: true },
        ],
      ]);
    });

    test("una lista vacía borra todas las jornadas sin tocar el rol", async () => {
      target({ reviewRole: "revisor" });

      const result = await call({ uid: "u1", shifts: [] });

      assert.deepEqual(result, { success: true });
      assert.deepEqual(written(), [[{ reviewShifts: [] }, { merge: true }]]);
    });
  });
});
