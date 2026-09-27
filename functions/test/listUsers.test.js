// Pruebas de listUsers con un Admin SDK falso (sin emulador ni Firebase real).
const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { db, allUsers, reset, rejectedWith } = require("./helpers/fakeAdmin");

const { listUsers } = require("../index.js");

const ADMIN = { uid: "caller", token: { admin: true } };
const ASSIGNMENT = {
  role: "revisor",
  chatJid: "120363000000000001@g.us",
  shift: "afternoon1",
};

function call(auth = ADMIN) {
  return listUsers.run({ auth, data: {}, rawRequest: {} });
}

function authUser(uid, customClaims, extra = {}) {
  return {
    uid,
    email: `${uid}@x.com`,
    displayName: uid,
    disabled: false,
    customClaims,
    ...extra,
  };
}

describe("listUsers", () => {
  beforeEach(() => reset());

  test("incluye reviewAssignment con valor", async () => {
    allUsers([authUser("u1", { reviewAssignment: ASSIGNMENT })]);

    const { users } = await call();

    assert.deepEqual(users[0].reviewAssignment, ASSIGNMENT);
  });

  test("reviewAssignment es null sin asignación o sin claims", async () => {
    allUsers([
      authUser("sin-claims", undefined),
      authUser("solo-admin", { admin: true }),
      authUser("nulo", { reviewAssignment: null }),
    ]);

    const { users } = await call();

    for (const user of users) {
      assert.equal(user.reviewAssignment, null, user.uid);
    }
  });

  test("lo demás de la respuesta no cambia", async () => {
    allUsers([
      authUser("u1", {
        admin: true,
        superAdmin: true,
        reviewAssignment: ASSIGNMENT,
      }),
      authUser("u2", undefined, { disabled: true, displayName: undefined }),
    ]);
    db.userDocs.u1 = { allowedGroups: ["g1"] };

    const { users } = await call();

    assert.deepEqual(users[0], {
      uid: "u1",
      email: "u1@x.com",
      displayName: "u1",
      disabled: false,
      isAdmin: true,
      isSuperAdmin: true,
      reviewAssignment: ASSIGNMENT,
      allowedGroups: ["g1"],
    });
    assert.deepEqual(users[1], {
      uid: "u2",
      email: "u2@x.com",
      displayName: "",
      disabled: true,
      isAdmin: false,
      isSuperAdmin: false,
      reviewAssignment: null,
      allowedGroups: [],
    });
  });

  test("sigue exigiendo admin", async () => {
    await assert.rejects(call({ uid: "x", token: {} }), rejectedWith("permission-denied"));
  });
});
