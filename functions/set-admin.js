const admin = require("firebase-admin");

// Los claims actuales se FUSIONAN: `setCustomUserClaims` reemplaza el objeto
// completo, así que escribir solo `{ admin, superAdmin }` borraría cualquier
// otro claim (por ejemplo `reviewRole`). Mismo patrón que `setUserRole`.
function mergeSuperAdminClaims(currentClaims) {
  return { ...(currentClaims ?? {}), admin: true, superAdmin: true };
}

async function setSuperAdmin(email, auth = admin.auth()) {
  const user = await auth.getUserByEmail(email);
  await auth.setCustomUserClaims(user.uid, mergeSuperAdminClaims(user.customClaims));
  console.log(`✅ ${email} ahora tiene admin + superAdmin`);
}

// Solo al ejecutarlo desde la línea de comandos (`node set-admin.js`) se carga
// la llave y se inicializa la app; importarlo (tests) no hace nada de eso.
if (require.main === module) {
  const serviceAccount = require("./serviceAccountKey.json");
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  setSuperAdmin("superadmin@gmail.com").then(() => process.exit(0));
}

module.exports = { mergeSuperAdminClaims, setSuperAdmin };
