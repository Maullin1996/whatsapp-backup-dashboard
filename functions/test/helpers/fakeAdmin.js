// Admin SDK falso compartido por los tests de functions/: sin emulador y sin
// tocar Firebase real. Se instala al hacer `require` de este módulo, así que
// cada archivo de test debe requerirlo ANTES de cargar `../index.js`.
//
// `auth` y `firestore` son getters de solo lectura en el prototipo del
// namespace de firebase-admin: se sombrean con propiedades propias.
const { mock } = require("node:test");
const admin = require("firebase-admin");

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
  listUsers: mock.fn(async () => ({ users: [] })),
};

const docSet = mock.fn(async () => {});
const docRef = mock.fn(() => ({ set: docSet }));

// Estado editable de Firestore.
const db = {
  /** chatJid de los documentos existentes en group_stats. */
  groups: new Set(),
  /** Documentos de `users/{uid}` por uid (para listUsers). */
  userDocs: {},
};

const groupQuery = mock.fn((field, op, value) => ({
  limit: () => ({
    get: async () => {
      const found = field === "chatJid" && op === "==" && db.groups.has(value);
      return {
        empty: !found,
        docs: found ? [{ data: () => ({ chatJid: value }) }] : [],
      };
    },
  }),
}));

const collection = mock.fn((name) =>
  name === "group_stats"
    ? { where: groupQuery }
    : { doc: (id) => ({ ...docRef(id), id }) }
);

const firestoreFake = () => ({
  collection,
  getAll: async (...refs) =>
    refs.map((ref) => ({
      id: ref.id,
      exists: ref.id in db.userDocs,
      data: () => db.userDocs[ref.id],
    })),
});
firestoreFake.FieldValue = { serverTimestamp: () => "SERVER_TIMESTAMP" };

defineFake("initializeApp", () => {});
defineFake("auth", () => authFake);
defineFake("firestore", firestoreFake);

/** El usuario objetivo tal como lo devuelve `admin.auth().getUser`. */
function target(customClaims) {
  authFake.getUser.mock.mockImplementation(async (uid) => ({
    uid,
    customClaims,
  }));
}

/** Usuarios que devuelve `admin.auth().listUsers`. */
function allUsers(users) {
  authFake.listUsers.mock.mockImplementation(async () => ({ users }));
}

function reset() {
  authFake.getUser.mock.resetCalls();
  authFake.setCustomUserClaims.mock.resetCalls();
  authFake.listUsers.mock.resetCalls();
  docSet.mock.resetCalls();
  docRef.mock.resetCalls();
  groupQuery.mock.resetCalls();
  db.groups.clear();
  db.userDocs = {};
  target(undefined);
  allUsers([]);
}

/** Predicado para `assert.rejects` que comprueba el código de HttpsError. */
function rejectedWith(code) {
  return (error) => {
    require("node:assert/strict").equal(error.code, code);
    return true;
  };
}

module.exports = {
  authFake,
  docSet,
  groupQuery,
  db,
  target,
  allUsers,
  reset,
  rejectedWith,
};
