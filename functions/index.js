const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

admin.initializeApp();

const firestore = admin.firestore();

// ─── Verificadores de rol ─────────────────────────────────────────────────────
function assertAdmin(request) {
  if (!request.auth?.token?.admin) {
    throw new HttpsError("permission-denied", "Se requiere rol de administrador.");
  }
}

function assertSuperAdmin(request) {
  if (!request.auth?.token?.superAdmin) {
    throw new HttpsError("permission-denied", "Solo el superusuario puede realizar esta acción.");
  }
}

// ─── Crear usuario ────────────────────────────────────────────────────────────
// Ahora cualquier admin puede crear usuarios normales
exports.createUser = onCall(async (request) => {
  assertAdmin(request);  // ← antes era assertSuperAdmin

  const { email, password, displayName } = request.data;
  if (!email || !password || !displayName) {
    throw new HttpsError("invalid-argument", "Email, contraseña y nombre son requeridos.");
  }

  try {
    const user = await admin.auth().createUser({
      email,
      password,
      displayName,
      emailVerified: true,
    });

    await firestore.collection("users").doc(user.uid).set({
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      disabled: false,
      allowedGroups: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? "",
      disabled: false,
      allowedGroups: [],
    };
  } catch (e) {
    console.error("❌ Error en createUser:", e.code, e.message);
    if (e.code === "auth/email-already-exists")
      throw new HttpsError("already-exists", "El correo ya está registrado.");
    if (e.code === "auth/invalid-password")
      throw new HttpsError("invalid-argument", "La contraseña debe tener al menos 6 caracteres.");
    if (e.code === "auth/invalid-email")
      throw new HttpsError("invalid-argument", "El correo no es válido.");
    throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
  }
});

// ─── Promover / degradar usuario ──────────────────────────────────────────────
// Solo superAdmin puede cambiar roles. Nunca se toca a otro superAdmin ni se
// pierden claims ajenos: se LEEN los claims actuales del usuario objetivo, se
// FUSIONAN cambiando solo `admin` y se escriben. (`setCustomUserClaims`
// reemplaza el objeto completo, así que escribir solo `{ admin }` borraría
// cualquier otro claim.) Cualquier función futura que toque claims debe seguir
// este mismo patrón: leer, fusionar, escribir.
exports.setUserRole = onCall(async (request) => {
  // Verificado en el servidor con el token de quien llama: ocultar el botón en
  // la app no protege una llamada directa a la función.
  assertSuperAdmin(request);

  const { uid, role } = request.data; // role: 'admin' | 'user'

  if (!uid || !["admin", "user"].includes(role)) {
    throw new HttpsError("invalid-argument", "uid y role ('admin' | 'user') son requeridos.");
  }

  const isAdmin = role === "admin";

  // Los claims del objetivo salen de Auth, nunca de lo que mande el cliente.
  let target;
  try {
    target = await admin.auth().getUser(uid);
  } catch (e) {
    if (e.code === "auth/user-not-found")
      throw new HttpsError("not-found", "El usuario no existe.");
    console.error("❌ Error en setUserRole:", e.code, e.message);
    throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
  }
  const currentClaims = target.customClaims ?? {};

  // superAdmin no se toca desde aquí (tampoco a uno mismo), pida lo que pida
  // el cliente.
  if (currentClaims.superAdmin === true) {
    throw new HttpsError(
      "permission-denied",
      "No se puede cambiar el rol de un superusuario."
    );
  }

  // Fusionar: solo cambia `admin`; el resto de claims se conserva.
  await admin.auth().setCustomUserClaims(uid, { ...currentClaims, admin: isAdmin });

  // Reflejar en Firestore para que listUsers lo muestre
  await firestore.collection("users").doc(uid).set(
    { isAdmin },
    { merge: true }
  );

  return { success: true };
});

// ─── Asignar / reasignar / desactivar Revisor o Sumador ───────────────────────
// Jornadas asignables. ESPEJO A MANO de `enum Shift` en
// lib/core/time/shifts.dart (se usan los nombres de los valores en Dart, no las
// etiquetas en español): hoy no hay ninguna fuente compartida entre Dart y
// functions/, así que esta lista DEBE mantenerse sincronizada a mano con
// shifts.dart hasta que las jornadas vengan del Firebase externo (ver
// .claude/skills/image-review-firebase-integration.md). `outOfShift` ("Fuera de
// las jornadas") se excluye a propósito: no es un turno real.
const ASSIGNABLE_SHIFTS = [
  "morning",
  "afternoon1",
  "afternoon2",
  "night1",
  "night2",
  "holiday",
];
const REVIEW_ROLES = ["revisor", "sumador"];

// Valida la forma de `assignment` (sin tocar Auth ni Firestore) y devuelve solo
// los tres campos conocidos, o null para "desactivar". Cualquier otra clave que
// mande el cliente se descarta: los claims se pagan en bytes (ver más abajo).
function parseAssignment(assignment) {
  if (assignment === undefined)
    throw new HttpsError(
      "invalid-argument",
      "assignment es requerido (null para desactivar la asignación)."
    );
  if (assignment === null) return null;

  if (typeof assignment !== "object" || Array.isArray(assignment))
    throw new HttpsError("invalid-argument", "assignment debe ser null o un objeto.");

  const { role, chatJid, shift } = assignment;
  if (!REVIEW_ROLES.includes(role))
    throw new HttpsError("invalid-argument", "role debe ser 'revisor' o 'sumador'.");
  if (typeof chatJid !== "string" || chatJid.trim() === "")
    throw new HttpsError("invalid-argument", "chatJid es requerido.");
  if (!ASSIGNABLE_SHIFTS.includes(shift))
    throw new HttpsError(
      "invalid-argument",
      `shift debe ser una de: ${ASSIGNABLE_SHIFTS.join(", ")}.`
    );
  return { role, chatJid, shift };
}

// Solo superAdmin. Un usuario tiene A LO SUMO una asignación (`reviewAssignment`
// = { role, chatJid, shift }, un único claim combinado), así que la exclusión
// mutua Revisor/Sumador es inherente: no existen dos claims que puedan quedar
// encendidos a la vez. Sigue el patrón de setUserRole: leer los claims con
// getUser, fusionar y escribir.
//
// A diferencia de setUserRole NO hay guarda contra un objetivo superAdmin: son
// claims independientes y a un superAdmin SÍ se le puede asignar Revisor/Sumador
// (intencional, cubierto con un test).
//
// Límite de Firebase: los custom claims completos de un usuario no pueden pasar
// de 1000 bytes. Ese presupuesto lo comparten admin, superAdmin y
// reviewAssignment (hoy sobra de lejos: un chatJid ronda los 30 caracteres). No
// hay enforcement activo; si se agregan claims grandes hay que revisarlo aquí.
exports.setReviewAssignment = onCall(async (request) => {
  assertSuperAdmin(request);

  const { uid, assignment } = request.data ?? {};
  if (typeof uid !== "string" || uid.trim() === "")
    throw new HttpsError("invalid-argument", "uid es requerido.");
  const parsed = parseAssignment(assignment);

  if (parsed !== null) {
    // El grupo debe existir. Se busca por el CAMPO `chatJid` (así lo consulta
    // todo el proyecto: listGroups, ChatsFirestoreDatasource) y no por id de
    // documento, porque en el repo no consta que el id de group_stats/{...}
    // sea el chatJid. Una sola lectura: ataja errores de tipeo.
    const group = await firestore
      .collection("group_stats")
      .where("chatJid", "==", parsed.chatJid)
      .limit(1)
      .get();
    if (group.empty)
      throw new HttpsError("not-found", "El grupo indicado no existe.");
  }

  // Los claims del objetivo salen de Auth, nunca de lo que mande el cliente.
  let target;
  try {
    target = await admin.auth().getUser(uid);
  } catch (e) {
    if (e.code === "auth/user-not-found")
      throw new HttpsError("not-found", "El usuario no existe.");
    console.error("❌ Error en setReviewAssignment:", e.code, e.message);
    throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
  }
  const currentClaims = target.customClaims ?? {};

  if (parsed !== null) {
    // Unicidad por (role, chatJid, shift): dos Revisores (o dos Sumadores)
    // nunca comparten grupo + jornada, pero un Revisor y un Sumador sí (deben).
    // Se recorren todos los usuarios de Auth: hereda el límite de 1000 de
    // listUsers (sin paginar). El propio uid se ignora, así reasignarle lo
    // mismo es idempotente.
    //
    // Riesgo aceptado: no hay transacción entre este chequeo y la escritura
    // (igual que el resto del archivo); dos llamadas simultáneas del
    // superAdmin podrían asignar el mismo (role, chatJid, shift) a dos
    // usuarios.
    const all = await admin.auth().listUsers(1000);
    const taken = all.users.some((u) => {
      const other = u.customClaims?.reviewAssignment;
      return (
        u.uid !== uid &&
        other?.role === parsed.role &&
        other?.chatJid === parsed.chatJid &&
        other?.shift === parsed.shift
      );
    });
    if (taken)
      throw new HttpsError(
        "already-exists",
        "Ese grupo y jornada ya tienen asignado a otro usuario con el mismo rol."
      );
  }

  // Fusionar: solo cambia `reviewAssignment`; el resto de claims se conserva.
  // Para desactivar se BORRA la clave en vez de escribir `null`: setCustomUserClaims
  // reemplaza el objeto completo, así que basta omitirla; queda una sola
  // representación de "sin asignación" (clave ausente), no ocupa bytes del
  // límite de 1000 y en el cliente `claims['reviewAssignment']` es simplemente
  // null.
  const { reviewAssignment: _previous, ...rest } = currentClaims;
  await admin
    .auth()
    .setCustomUserClaims(uid, parsed === null ? rest : { ...rest, reviewAssignment: parsed });

  return { success: true };
});

// ─── Cambiar contraseña ───────────────────────────────────────────────────────
exports.updateUserPassword = onCall(async (request) => {
  assertAdmin(request);
  const { uid, newPassword } = request.data;
  if (!uid || !newPassword)
    throw new HttpsError("invalid-argument", "uid y newPassword son requeridos.");
  await admin.auth().updateUser(uid, { password: newPassword });
  return { success: true };
});

// ─── Eliminar usuario ─────────────────────────────────────────────────────────
exports.deleteUser = onCall(async (request) => {
  assertAdmin(request);
  const { uid } = request.data;
  if (!uid) throw new HttpsError("invalid-argument", "uid es requerido.");
  try {
    await admin.auth().deleteUser(uid);
    await firestore.collection("users").doc(uid).delete();
    return { success: true };
  } catch (e) {
    console.error("❌ Error en deleteUser:", e.code, e.message);
    throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
  }
});

// ─── Listar usuarios ──────────────────────────────────────────────────────────
exports.listUsers = onCall(async (request) => {
  assertAdmin(request);

  const authResult = await admin.auth().listUsers(1000);
  const uids = authResult.users.map((u) => u.uid);

  let firestoreDocs = {};
  if (uids.length > 0) {
    const chunks = [];
    for (let i = 0; i < uids.length; i += 30) chunks.push(uids.slice(i, i + 30));
    for (const chunk of chunks) {
      const refs = chunk.map((uid) => firestore.collection("users").doc(uid));
      const docs = await firestore.getAll(...refs);
      docs.forEach((doc) => { if (doc.exists) firestoreDocs[doc.id] = doc.data(); });
    }
  }

  const users = authResult.users.map((u) => ({
    uid: u.uid,
    email: u.email ?? "",
    displayName: u.displayName ?? "",
    disabled: u.disabled,
    // ← leemos los claims directamente de Auth, no de Firestore
    isAdmin: u.customClaims?.admin === true,
    isSuperAdmin: u.customClaims?.superAdmin === true,
    // Asignación de Revisor/Sumador ({ role, chatJid, shift }) o null.
    reviewAssignment: u.customClaims?.reviewAssignment ?? null,
    allowedGroups: firestoreDocs[u.uid]?.allowedGroups ?? [],
  }));

  return { users };
});

// ─── Habilitar / deshabilitar usuario ─────────────────────────────────────────
exports.toggleUserStatus = onCall(async (request) => {
  assertAdmin(request);
  const { uid, disabled } = request.data;
  if (!uid || disabled === undefined)
    throw new HttpsError("invalid-argument", "uid y disabled son requeridos.");
  await admin.auth().updateUser(uid, { disabled });
  await firestore.collection("users").doc(uid).set({ disabled }, { merge: true });
  return { success: true };
});

// ─── Asignar grupos ───────────────────────────────────────────────────────────
exports.updateUserGroups = onCall(async (request) => {
  assertAdmin(request);
  const { uid, allowedGroups } = request.data;
  if (!uid || !Array.isArray(allowedGroups))
    throw new HttpsError("invalid-argument", "uid y allowedGroups (array) son requeridos.");
  await firestore.collection("users").doc(uid).set({ allowedGroups }, { merge: true });
  return { success: true };
});

// ─── Listar grupos ────────────────────────────────────────────────────────────
exports.listGroups = onCall(async (request) => {
  assertAdmin(request);
  const snapshot = await firestore.collection("group_stats").orderBy("groupName").get();
  const groups = snapshot.docs.map((doc) => ({
    chatJid: doc.data().chatJid,
    groupName: doc.data().groupName,
  }));
  return { groups };
});