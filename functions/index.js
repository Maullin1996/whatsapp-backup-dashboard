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

// ─── Rol y jornadas de revisión (Revisor / Sumador) ────────────────────────
// Reemplaza al antiguo `setReviewAssignment` (un solo claim combinado
// {role, chatJid, shift}, como mucho UNA asignación por persona). Se
// descartó por datos reales: una cuenta de Revisor/Sumador cubre VARIOS
// grupos, algunos repetidos entre personas del mismo rol cubriendo jornadas
// distintas de ese grupo — no cabe en una tupla única. Ahora el rol vive en
// un custom claim simple (`reviewRole`) y la LISTA de (grupo, jornada) que
// esa persona cubre vive en Firestore (`users/{uid}.reviewShifts`), separado
// en dos funciones. Ver .claude/skills/image-review-roles.md, sección
// "Asignación de grupo + jornada".
//
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

// Solo superAdmin. Sigue el patrón de setUserRole: leer los claims del
// objetivo con getUser, fusionar cambiando solo `reviewRole`, escribir (para
// desactivar se BORRA la clave, no se escribe `null` — misma representación
// que usaba `reviewAssignment`). A diferencia de setUserRole, SIN guarda
// contra un objetivo superAdmin: un superAdmin SÍ puede tener rol de
// revisión (igual que en el extinto setReviewAssignment, intencional).
exports.setReviewRole = onCall(async (request) => {
  assertSuperAdmin(request);

  const { uid, role } = request.data ?? {}; // role: 'revisor' | 'sumador' | null
  if (typeof uid !== "string" || uid.trim() === "")
    throw new HttpsError("invalid-argument", "uid es requerido.");
  if (role !== null && !REVIEW_ROLES.includes(role))
    throw new HttpsError(
      "invalid-argument",
      "role debe ser 'revisor', 'sumador' o null."
    );

  // Los claims del objetivo salen de Auth, nunca de lo que mande el cliente.
  let target;
  try {
    target = await admin.auth().getUser(uid);
  } catch (e) {
    if (e.code === "auth/user-not-found")
      throw new HttpsError("not-found", "El usuario no existe.");
    console.error("❌ Error en setReviewRole:", e.code, e.message);
    throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
  }
  const currentClaims = target.customClaims ?? {};
  const previousRole = currentClaims.reviewRole ?? null;

  // Fusionar: solo cambia `reviewRole`; el resto de claims se conserva.
  const { reviewRole: _previous, ...rest } = currentClaims;
  await admin
    .auth()
    .setCustomUserClaims(uid, role === null ? rest : { ...rest, reviewRole: role });

  // El rol CAMBIÓ de verdad (no una reasignación del mismo valor, que no
  // hace nada): las jornadas que cubría bajo el rol anterior ya no tienen
  // sentido bajo el nuevo, se limpian. Riesgo aceptado (ya conocido en el
  // proyecto, no se resuelve con infraestructura nueva): esta escritura no
  // es atómica con la de Auth de arriba — son dos sistemas distintos.
  if (role !== previousRole) {
    await firestore
      .collection("users")
      .doc(uid)
      .set({ reviewShifts: [] }, { merge: true });
  }

  return { success: true };
});

// Valida la forma de `shifts` (sin tocar Auth ni Firestore): un array de
// `{chatJid, shift}`, sin `role` por entrada (se deriva del `reviewRole`
// actual del uid objetivo, un usuario no puede cubrir un grupo+jornada bajo
// un rol que no es el suyo).
function parseShifts(shifts) {
  if (!Array.isArray(shifts))
    throw new HttpsError("invalid-argument", "shifts debe ser un array.");
  return shifts.map((entry) => {
    if (typeof entry !== "object" || entry === null || Array.isArray(entry))
      throw new HttpsError(
        "invalid-argument",
        "Cada entrada de shifts debe ser un objeto {chatJid, shift}."
      );
    const { chatJid, shift } = entry;
    if (typeof chatJid !== "string" || chatJid.trim() === "")
      throw new HttpsError("invalid-argument", "chatJid es requerido en cada entrada.");
    if (!ASSIGNABLE_SHIFTS.includes(shift))
      throw new HttpsError(
        "invalid-argument",
        `shift debe ser una de: ${ASSIGNABLE_SHIFTS.join(", ")}.`
      );
    return { chatJid, shift };
  });
}

// Solo superAdmin. Reemplaza TODA la lista de (grupo, jornada) que cubre un
// Revisor/Sumador (patrón de updateUserGroups: reemplazo completo, no merge
// parcial — una entrada vieja que no viene en el payload nuevo desaparece).
// Exige que el objetivo ya tenga `reviewRole` asignado (con setReviewRole):
// sin rol no hay bajo qué unicidad evaluar las jornadas.
exports.updateReviewShifts = onCall(async (request) => {
  assertSuperAdmin(request);

  const { uid, shifts } = request.data ?? {};
  if (typeof uid !== "string" || uid.trim() === "")
    throw new HttpsError("invalid-argument", "uid es requerido.");
  const parsed = parseShifts(shifts);

  // El rol sale de Auth (fuente de verdad), nunca de lo que mande el cliente.
  let target;
  try {
    target = await admin.auth().getUser(uid);
  } catch (e) {
    if (e.code === "auth/user-not-found")
      throw new HttpsError("not-found", "El usuario no existe.");
    console.error("❌ Error en updateReviewShifts:", e.code, e.message);
    throw new HttpsError("internal", e.message ?? "Error interno del servidor.");
  }
  const role = target.customClaims?.reviewRole ?? null;
  if (role === null)
    throw new HttpsError(
      "failed-precondition",
      "El usuario no tiene un rol de revisión asignado."
    );

  // Cada grupo debe existir. Se busca por el CAMPO `chatJid` (como el resto
  // del proyecto), una consulta por entrada: la cantidad de grupos por
  // persona es chica en la práctica (unos pocos), no vale la pena un `in`
  // batched todavía.
  for (const { chatJid } of parsed) {
    const group = await firestore
      .collection("group_stats")
      .where("chatJid", "==", chatJid)
      .limit(1)
      .get();
    if (group.empty)
      throw new HttpsError("not-found", `El grupo ${chatJid} no existe.`);
  }

  // Unicidad por (reviewRole, chatJid, shift): dos personas del MISMO rol no
  // pueden cubrir el mismo grupo+jornada; Revisor y Sumador sí (deben,
  // se verifican mutuamente). Para no pagar una segunda pasada completa de
  // listUsers ni escanear toda la colección `users`:
  //   1. Un solo listUsers(1000) ya trae el `reviewRole` de todos (gratis,
  //      viene en los claims).
  //   2. Se filtra a los uids con reviewRole (típicamente un subconjunto
  //      chico de todos los usuarios), excluyendo el propio uid.
  //   3. Un solo getAll en lotes de 30 sobre ESOS uids trae sus
  //      `reviewShifts` de Firestore (mismo patrón de listUsers).
  // Riesgo aceptado (igual que el resto del archivo): sin transacción entre
  // este chequeo y la escritura; hereda el tope de 1000 usuarios de
  // listUsers (sin paginar).
  const all = await admin.auth().listUsers(1000);
  const reviewers = all.users.filter(
    (u) => u.uid !== uid && u.customClaims?.reviewRole
  );

  const occupied = new Set();
  for (let i = 0; i < reviewers.length; i += 30) {
    const chunk = reviewers.slice(i, i + 30);
    const refs = chunk.map((u) => firestore.collection("users").doc(u.uid));
    const docs = await firestore.getAll(...refs);
    docs.forEach((doc, index) => {
      if (!doc.exists) return;
      const otherRole = chunk[index].customClaims.reviewRole;
      const otherShifts = doc.data().reviewShifts ?? [];
      for (const { chatJid, shift } of otherShifts) {
        occupied.add(`${otherRole}|${chatJid}|${shift}`);
      }
    });
  }

  // Rechazo todo-o-nada (como updateUserGroups): si hay cualquier choque no
  // se escribe nada, y se listan TODOS los conflictos en los detalles del
  // error, no solo el primero, para que el cliente los marque de una sola
  // vez sin reintentos en serie.
  const conflicts = parsed.filter(({ chatJid, shift }) =>
    occupied.has(`${role}|${chatJid}|${shift}`)
  );
  if (conflicts.length > 0)
    throw new HttpsError(
      "already-exists",
      "Uno o más grupos y jornadas ya tienen asignado a otro usuario con el mismo rol.",
      { conflicts }
    );

  await firestore.collection("users").doc(uid).set(
    { reviewShifts: parsed },
    { merge: true }
  );

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
    // Rol de revisión ('revisor' | 'sumador' | null) y la lista de (grupo,
    // jornada) que cubre bajo ese rol — mismo lote de getAll de arriba, sin
    // pasada extra.
    reviewRole: u.customClaims?.reviewRole ?? null,
    reviewShifts: firestoreDocs[u.uid]?.reviewShifts ?? [],
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