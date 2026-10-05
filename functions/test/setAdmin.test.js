// Pruebas de set-admin.js con un Auth falso: no ejecutan el script, no cargan
// la llave ni tocan Firebase. Se ejecutan con `npm test`.
const { test, describe, beforeEach, mock } = require("node:test");
const assert = require("node:assert/strict");
const path = require("node:path");

const { mergeSuperAdminClaims, setSuperAdmin } = require("../set-admin.js");

function fakeAuth(user) {
  return {
    getUserByEmail: mock.fn(async (email) => {
      if (!user) {
        throw Object.assign(new Error("no existe"), { code: "auth/user-not-found" });
      }
      return { uid: user.uid, email, customClaims: user.customClaims };
    }),
    setCustomUserClaims: mock.fn(async () => {}),
  };
}

describe("set-admin.js", () => {
  beforeEach(() => {
    mock.method(console, "log", () => {});
  });

  test("importarlo no carga la llave", () => {
    const keyPath = path.resolve(__dirname, "..", "serviceAccountKey.json");
    assert.equal(require.cache[keyPath], undefined);
  });

  test("conserva reviewRole y agrega superAdmin (y admin, como antes)", async () => {
    const auth = fakeAuth({ uid: "u1", customClaims: { reviewRole: "revisor" } });

    await setSuperAdmin("a@gmail.com", auth);

    assert.equal(auth.setCustomUserClaims.mock.callCount(), 1);
    assert.deepEqual(auth.setCustomUserClaims.mock.calls[0].arguments, [
      "u1",
      { reviewRole: "revisor", admin: true, superAdmin: true },
    ]);
  });

  test("un usuario con admin lo conserva", async () => {
    const auth = fakeAuth({ uid: "u2", customClaims: { admin: true, otro: 1 } });

    await setSuperAdmin("b@gmail.com", auth);

    assert.deepEqual(auth.setCustomUserClaims.mock.calls[0].arguments[1], {
      admin: true,
      otro: 1,
      superAdmin: true,
    });
  });

  test("un usuario sin claims recibe solo los claims del script", async () => {
    const auth = fakeAuth({ uid: "u3", customClaims: undefined });

    await setSuperAdmin("c@gmail.com", auth);

    assert.deepEqual(auth.setCustomUserClaims.mock.calls[0].arguments[1], {
      admin: true,
      superAdmin: true,
    });
  });

  test("no modifica el objeto original de claims", () => {
    const original = { reviewRole: "sumador" };
    const before = JSON.stringify(original);

    const merged = mergeSuperAdminClaims(original);

    assert.equal(JSON.stringify(original), before);
    assert.notEqual(merged, original);
  });

  test("si el usuario no existe, falla sin escribir", async () => {
    const auth = fakeAuth(null);

    await assert.rejects(setSuperAdmin("nadie@gmail.com", auth), {
      code: "auth/user-not-found",
    });
    assert.equal(auth.setCustomUserClaims.mock.callCount(), 0);
  });
});
