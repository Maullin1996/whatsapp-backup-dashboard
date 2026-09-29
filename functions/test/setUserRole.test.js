// Pruebas de setUserRole con un Admin SDK falso: no usan el emulador ni tocan
// Firebase real. Se ejecutan con `npm test` (runner integrado de Node).
const { test, describe, beforeEach, mock } = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

// `auth` y `firestore` son getters de solo lectura en el prototipo del
// namespace: se sombrean con propiedades propias ANTES de cargar index.js.
function defineFake(name, value) {
  Object.defineProperty(admin, name, {
    value,
    configurable: true,
    writable: true,
  });
}

const authFake = {
  getUser: mock.fn(),
  setCustomUserClaims: mock.fn(async () => {}),
};
const docSet = mock.fn(async () => {});
const docRef = mock.fn(() => ({ set: docSet }));
const firestoreFake = () => ({
  collection: () => ({ doc: docRef }),
});
firestoreFake.FieldValue = { serverTimestamp: () => "SERVER_TIMESTAMP" };

defineFake("initializeApp", () => {});
defineFake("auth", () => authFake);
defineFake("firestore", firestoreFake);

const { setUserRole } = require("../index.js");

const SUPER = { uid: "caller", token: { admin: true, superAdmin: true } };

function call(data, auth = SUPER) {
  return setUserRole.run({ auth, data, rawRequest: {} });
}

/** El usuario objetivo tal como lo devuelve `admin.auth().getUser`. */
function target(customClaims) {
  authFake.getUser.mock.mockImplementation(async (uid) => ({
    uid,
    customClaims,
  }));
}

function rejectedWith(code) {
  return (error) => {
    assert.equal(error.code, code);
    return true;
  };
}

describe("setUserRole", () => {
  beforeEach(() => {
    authFake.getUser.mock.resetCalls();
    authFake.setCustomUserClaims.mock.resetCalls();
    docSet.mock.resetCalls();
    docRef.mock.resetCalls();
    target(undefined);
  });

  describe("no toca a un superAdmin", () => {
    for (const role of ["admin", "user"]) {
      test(`rechaza role '${role}' sobre {superAdmin: true} y no escribe nada`, async () => {
        target({ admin: true, superAdmin: true });

        await assert.rejects(
          call({ uid: "u1", role }),
          rejectedWith("permission-denied"),
        );

        assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
        assert.equal(docSet.mock.callCount(), 0);
      });
    }

    test("rechaza aunque el superAdmin no tenga admin en sus claims", async () => {
      target({ superAdmin: true });

      await assert.rejects(
        call({ uid: "u1", role: "admin" }),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("un superAdmin no puede cambiarse el rol a sí mismo", async () => {
      target({ admin: true, superAdmin: true });

      await assert.rejects(
        call({ uid: SUPER.uid, role: "user" }),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("decide con los claims del servidor, no con lo que mande el cliente", async () => {
      target({ admin: true, superAdmin: true });

      await assert.rejects(
        call({ uid: "u1", role: "user", superAdmin: false, claims: {} }),
        rejectedWith("permission-denied"),
      );
      assert.equal(
        authFake.getUser.mock.calls[0].arguments[0],
        "u1",
        "lee al usuario objetivo",
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });
  });

  describe("fusiona los claims, no los reemplaza", () => {
    test("{revisor: true} + role 'admin' => {revisor: true, admin: true}", async () => {
      target({ revisor: true });

      const result = await call({ uid: "u1", role: "admin" });

      assert.deepEqual(result, { success: true });
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 1);
      assert.deepEqual(authFake.setCustomUserClaims.mock.calls[0].arguments, [
        "u1",
        { revisor: true, admin: true },
      ]);
    });

    test("quitar admin conserva los demás claims", async () => {
      target({ admin: true, revisor: true, otro: "x" });

      await call({ uid: "u1", role: "user" });

      assert.deepEqual(authFake.setCustomUserClaims.mock.calls[0].arguments, [
        "u1",
        { admin: false, revisor: true, otro: "x" },
      ]);
    });

    test("un usuario sin claims recibe solo {admin}", async () => {
      target(undefined);

      await call({ uid: "u1", role: "admin" });

      assert.deepEqual(authFake.setCustomUserClaims.mock.calls[0].arguments, [
        "u1",
        { admin: true },
      ]);
    });

    test("no modifica el objeto de claims que devolvió Auth", async () => {
      const original = { sumador: true };
      target(original);

      await call({ uid: "u1", role: "admin" });

      assert.deepEqual(original, { sumador: true });
    });
  });

  describe("espejo en Firestore", () => {
    test("escribe isAdmin con merge en users/{uid} después de los claims", async () => {
      target({ revisor: true });

      await call({ uid: "u1", role: "admin" });

      assert.equal(docRef.mock.calls[0].arguments[0], "u1");
      assert.deepEqual(docSet.mock.calls[0].arguments, [
        { isAdmin: true },
        { merge: true },
      ]);
    });
  });

  describe("quién llama", () => {
    test("un admin que no es superAdmin es rechazado sin leer ni escribir", async () => {
      await assert.rejects(
        call({ uid: "u1", role: "admin" }, { uid: "a", token: { admin: true } }),
        rejectedWith("permission-denied"),
      );

      assert.equal(authFake.getUser.mock.callCount(), 0);
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("sin sesión es rechazado", async () => {
      await assert.rejects(
        call({ uid: "u1", role: "admin" }, null),
        rejectedWith("permission-denied"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });
  });

  describe("argumentos", () => {
    test("role inválido o uid faltante => invalid-argument", async () => {
      await assert.rejects(
        call({ uid: "u1", role: "revisor" }),
        rejectedWith("invalid-argument"),
      );
      await assert.rejects(
        call({ role: "admin" }),
        rejectedWith("invalid-argument"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
    });

    test("usuario inexistente => not-found y no escribe", async () => {
      authFake.getUser.mock.mockImplementation(async () => {
        const error = new Error("no user");
        error.code = "auth/user-not-found";
        throw error;
      });

      await assert.rejects(
        call({ uid: "nadie", role: "admin" }),
        rejectedWith("not-found"),
      );
      assert.equal(authFake.setCustomUserClaims.mock.callCount(), 0);
      assert.equal(docSet.mock.callCount(), 0);
    });
  });
});
