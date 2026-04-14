const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

const firestore = admin.firestore();

// ─── Verificador de admin ─────────────────────────────────────────────────────
function assertAdmin(request) {
  if (!request.auth?.token?.admin) {
    throw new HttpsError(
      "permission-denied",
      "Solo el superusuario puede realizar esta acción."
    );
  }
}

// ─── Crear usuario ────────────────────────────────────────────────────────────
exports.createUser = onCall(async (request) => {
  assertAdmin(request);

  const { email, password, displayName } = request.data;

  if (!email || !password || !displayName) {
    throw new HttpsError("invalid-argument", "Email, contraseña y nombre son requeridos.");
  }

  try {
    // Crear en Firebase Auth
    const user = await admin.auth().createUser({
      email,
      password,
      displayName,
      emailVerified: true,
    });

    console.log("✅ Usuario creado en Auth:", user.uid);

    // Crear documento en Firestore
    await firestore.collection("users").doc(user.uid).set({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      disabled: false,
      allowedGroups: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("✅ Documento creado en Firestore:", user.uid);

    return {
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? "",
      disabled: false,
      allowedGroups: [],
    };
  } catch (e) {
    console.error("❌ Error en createUser:", e.code, e.message);
    
    // Mapear errores conocidos de Auth
    if (e.code === "auth/email-already-exists") {
      throw new HttpsError("already-exists", "El correo ya está registrado.");
    }
    if (e.code === "auth/invalid-password") {
      throw new HttpsError("invalid-argument", "La contraseña debe tener al menos 6 caracteres.");
    }
    if (e.code === "auth/invalid-email") {
      throw new HttpsError("invalid-argument", "El correo no es válido.");
    }

    throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
  }
});

// ─── Cambiar contraseña ───────────────────────────────────────────────────────
exports.updateUserPassword = onCall(async (request) => {
  assertAdmin(request);

  const { uid, newPassword } = request.data;

  if (!uid || !newPassword) {
    throw new HttpsError("invalid-argument", "uid y newPassword son requeridos.");
  }

  await admin.auth().updateUser(uid, { password: newPassword });

  return { success: true };
});

// ─── Eliminar usuario ───────────────────────────────────────────────────────
exports.deleteUser = onCall(
  { invoker: "public" },
  async (request) => {
    assertAdmin(request);

    const { uid } = request.data;

    if (!uid) {
      throw new HttpsError("invalid-argument", "uid es requerido.");
    }

    try {
      // Eliminar de Firebase Auth
      await admin.auth().deleteUser(uid);

      // Eliminar documento de Firestore
      await firestore.collection("users").doc(uid).delete();

      return { success: true };
    } catch (e) {
      console.error("❌ Error en deleteUser:", e.code, e.message);
      throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
    }
  }
);

// ─── Listar usuarios ──────────────────────────────────────────────────────────
exports.listUsers = onCall(async (request) => {
  assertAdmin(request);

  // Traer usuarios de Auth
  const authResult = await admin.auth().listUsers(1000);

  // Traer docs de Firestore para obtener allowedGroups
  const uids = authResult.users.map((u) => u.uid);

  let firestoreDocs = {};
  if (uids.length > 0) {
    // Firestore solo permite 30 docs por getAll, dividir en chunks
    const chunks = [];
    for (let i = 0; i < uids.length; i += 30) {
      chunks.push(uids.slice(i, i + 30));
    }

    for (const chunk of chunks) {
      const refs = chunk.map((uid) => firestore.collection("users").doc(uid));
      const docs = await firestore.getAll(...refs);
      docs.forEach((doc) => {
        if (doc.exists) {
          firestoreDocs[doc.id] = doc.data();
        }
      });
    }
  }

  const users = authResult.users.map((u) => ({
    uid: u.uid,
    email: u.email ?? "",
    displayName: u.displayName ?? "",
    disabled: u.disabled,
    allowedGroups: firestoreDocs[u.uid]?.allowedGroups ?? [],
  }));

  return { users };
});

// ─── Habilitar / deshabilitar usuario ─────────────────────────────────────────
exports.toggleUserStatus = onCall(async (request) => {
  assertAdmin(request);

  const { uid, disabled } = request.data;

  if (!uid || disabled === undefined) {
    throw new HttpsError("invalid-argument", "uid y disabled son requeridos.");
  }

  // Actualizar en Auth
  await admin.auth().updateUser(uid, { disabled });

  // Actualizar en Firestore
  await firestore.collection("users").doc(uid).set(
    { disabled },
    { merge: true }
  );

  return { success: true };
});

// ─── Asignar grupos a un usuario ──────────────────────────────────────────────
exports.updateUserGroups = onCall(async (request) => {
  assertAdmin(request);

  const { uid, allowedGroups } = request.data;

  if (!uid || !Array.isArray(allowedGroups)) {
    throw new HttpsError("invalid-argument", "uid y allowedGroups (array) son requeridos.");
  }

  await firestore.collection("users").doc(uid).set(
    { allowedGroups },
    { merge: true }
  );

  return { success: true };
});

// ─── Listar grupos disponibles ────────────────────────────────────────────────
exports.listGroups = onCall(async (request) => {
  assertAdmin(request);

  const snapshot = await firestore
    .collection("group_stats")
    .orderBy("groupName")
    .get();

  const groups = snapshot.docs.map((doc) => ({
    chatJid: doc.data().chatJid,
    groupName: doc.data().groupName,
  }));

  return { groups };
});