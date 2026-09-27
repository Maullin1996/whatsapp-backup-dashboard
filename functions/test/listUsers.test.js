// Pruebas de listUsers con un Admin SDK falso (sin emulador ni Firebase real).
const { test, describe, beforeEach } = require("node:test");
const assert = require("node:assert/strict");
const { db, allUsers, reset, rejectedWith } = require("./helpers/fakeAdmin");

const { listUsers } = require("../index.js");

const ADMIN = { uid: "caller", token: { admin: true } };
const SHIFTS = [{ chatJid: "120363000000000001@g.us", shift: "afternoon1" }];

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

  test("incluye reviewRole y reviewShifts con valores", async () => {
    allUsers([authUser("u1", { reviewRole: "revisor" })]);
    db.userDocs.u1 = { reviewShifts: SHIFTS };

    const { users } = await call();

    assert.equal(users[0].reviewRole, "revisor");
    assert.deepEqual(users[0].reviewShifts, SHIFTS);
  });

  test("reviewRole es null y reviewShifts es [] sin datos o sin claims", async () => {
    allUsers([
      authUser("sin-claims", undefined),
      authUser("solo-admin", { admin: true }),
      authUser("nulo", { reviewRole: null }),
    ]);

    const { users } = await call();

    for (const user of users) {
      assert.equal(user.reviewRole, null, user.uid);
      assert.deepEqual(user.reviewShifts, [], user.uid);
    }
  });

  test("lo demás de la respuesta no cambia", async () => {
    allUsers([
      authUser("u1", {
        admin: true,
        superAdmin: true,
        reviewRole: "revisor",
      }),
      authUser("u2", undefined, { disabled: true, displayName: undefined }),
    ]);
    db.userDocs.u1 = { allowedGroups: ["g1"], reviewShifts: SHIFTS };

    const { users } = await call();

    assert.deepEqual(users[0], {
      uid: "u1",
      email: "u1@x.com",
      displayName: "u1",
      disabled: false,
      isAdmin: true,
      isSuperAdmin: true,
      reviewRole: "revisor",
      reviewShifts: SHIFTS,
      allowedGroups: ["g1"],
    });
    assert.deepEqual(users[1], {
      uid: "u2",
      email: "u2@x.com",
      displayName: "",
      disabled: true,
      isAdmin: false,
      isSuperAdmin: false,
      reviewRole: null,
      reviewShifts: [],
      allowedGroups: [],
    });
  });

  test("sigue exigiendo admin", async () => {
    await assert.rejects(call({ uid: "x", token: {} }), rejectedWith("permission-denied"));
  });
});
