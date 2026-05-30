const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

async function setSuperAdmin(email) {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, {
    admin: true,
    superAdmin: true,
  });
  console.log(`✅ ${email} ahora tiene admin + superAdmin`);
  process.exit(0);
}

setSuperAdmin("superadmin@gmail.com");