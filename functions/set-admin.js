const admin = require("firebase-admin");
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function setAdmin(email) {
  const user = await admin.auth().getUserByEmail(email);
  await admin.auth().setCustomUserClaims(user.uid, { admin: true });
  console.log(`✅ Listo: ${email} ahora es superusuario`);
  process.exit(0);
}

// 👇 Cambia esto por el correo del superusuario
setAdmin("correodeprueba@gmail.com");