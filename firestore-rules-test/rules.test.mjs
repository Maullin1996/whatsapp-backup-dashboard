// Pruebas de firestore.rules.draft COMPLETO en el emulador local (proyecto
// demo-, nunca toca whatsapp-pro-3d483). Ver README.md.
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, collection, collectionGroup, query, where, getDocs,
} from 'firebase/firestore';

// Por defecto, el borrador del repo; RULES_PATH permite probar otra copia.
const RULES =
  process.env.RULES_PATH ??
  fileURLToPath(new URL('../firestore.rules.draft', import.meta.url));
const G1 = '120363000000000001@g.us';
const G2 = '120363000000000002@g.us';
const J_MORNING = '2026-10-04_morning';
const J_AFTERNOON = '2026-10-04_afternoon1';

const env = await initializeTestEnvironment({
  projectId: 'demo-review-rules',
  firestore: { rules: readFileSync(RULES, 'utf8'), host: '127.0.0.1', port: 8080 },
});

const registro = (messageId, rol, chatJid, shiftKey, ts = 1791100000000) => ({
  messageId, chatJid, shift: 'Jornada', shiftKey, rol,
  storagePath: `img_${messageId}.jpg`, fechaJornada: '2026-10-04',
  messageTimestamp: ts, codigo: 'A1',
  comprobantes: [{ numeros: ['0123'], total: 9000, loteria: null }],
  anotaciones: null, registradoEn: '2026-10-04T10:00:00.000Z',
  registradoPor: `${rol}@x.com`, editado: false,
});
const ruta = (chatJid, jornada, id) =>
  `image_reviews/${chatJid}/jornadas/${jornada}/registros/${id}`;

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/rev1'), { reviewShifts: [{ chatJid: G1, shift: 'morning' }] });
  await setDoc(doc(db, 'users/sum1'), { reviewShifts: [{ chatJid: G1, shift: 'morning' }] });
  await setDoc(doc(db, 'users/rev2'), { reviewShifts: [{ chatJid: G2, shift: 'morning' }] });
  await setDoc(doc(db, 'users/rev3'), { reviewShifts: [{ chatJid: G1, shift: 'afternoon1' }] });
  await setDoc(doc(db, 'users/revVacio'), { reviewShifts: [] });
  // revSinDoc: no tiene documento en users.
  await setDoc(doc(db, ruta(G1, J_MORNING, 'm1_revisor')), registro('m1', 'revisor', G1, 'morning'));
  await setDoc(doc(db, ruta(G1, J_MORNING, 'm1_sumador')), registro('m1', 'sumador', G1, 'morning'));
  await setDoc(doc(db, ruta(G1, J_AFTERNOON, 'm2_revisor')), registro('m2', 'revisor', G1, 'afternoon1'));
  await setDoc(doc(db, 'whatsapp_messages/m9'), { chatJid: G1, messageTimestamp: 1791100000009 });
  await setDoc(doc(db, 'jornadas/manana'), { name: 'Mañana' });
});

const as = (uid, claims) => env.authenticatedContext(uid, claims).firestore();
const rev1 = as('rev1', { reviewRole: 'revisor' });
const sum1 = as('sum1', { reviewRole: 'sumador' });
const rev2 = as('rev2', { reviewRole: 'revisor' });
const rev3 = as('rev3', { reviewRole: 'revisor' });
const revVacio = as('revVacio', { reviewRole: 'revisor' });
const revSinDoc = as('revSinDoc', { reviewRole: 'revisor' });
const sinRol = as('rev1', {}); // mismo uid asignado, pero sin claim reviewRole
const admin = as('adm', { admin: true });
const superAdmin = as('sup', { superAdmin: true });
const anon = env.unauthenticatedContext().firestore();

const registros = (db, chatJid, jornada) =>
  collection(db, `image_reviews/${chatJid}/jornadas/${jornada}/registros`);
const porRol = (db, chatJid, jornada, rol) =>
  query(registros(db, chatJid, jornada), where('rol', '==', rol));
const delDia = (db) =>
  query(collectionGroup(db, 'registros'), where('fechaJornada', '==', '2026-10-04'));

const casos = [];
const caso = (nombre, esperado, fn) => casos.push({ nombre, esperado, fn });

// 1. Sumador asignado NO lee registros del Revisor.
caso('1a Sumador asignado consulta rol==revisor', 'NIEGA', () => getDocs(porRol(sum1, G1, J_MORNING, 'revisor')));
caso('1b Sumador asignado lee m1_revisor por id', 'NIEGA', () => getDoc(doc(sum1, ruta(G1, J_MORNING, 'm1_revisor'))));
caso('1c Sumador asignado consulta sin filtro de rol', 'NIEGA', () => getDocs(registros(sum1, G1, J_MORNING)));
caso('1d Sumador asignado consulta rol==sumador (los suyos)', 'PERMITE', () => getDocs(porRol(sum1, G1, J_MORNING, 'sumador')));
// 2. Revisor asignado lee los suyos.
caso('2a Revisor asignado consulta rol==revisor', 'PERMITE', () => getDocs(porRol(rev1, G1, J_MORNING, 'revisor')));
caso('2b Revisor asignado lee m1_revisor por id', 'PERMITE', () => getDoc(doc(rev1, ruta(G1, J_MORNING, 'm1_revisor'))));
caso('2c Revisor asignado lee m1_sumador por id', 'NIEGA', () => getDoc(doc(rev1, ruta(G1, J_MORNING, 'm1_sumador'))));
caso('2d Revisor asignado consulta rol==sumador', 'NIEGA', () => getDocs(porRol(rev1, G1, J_MORNING, 'sumador')));
caso('2f Revisor asignado lee por id un registro que NO existe', 'NIEGA', () => getDoc(doc(rev1, ruta(G1, J_MORNING, 'noexiste_revisor'))));
caso('2e Revisor asignado consulta una jornada vacía (2026-10-05_morning)', 'PERMITE', () => getDocs(porRol(rev1, G1, '2026-10-05_morning', 'revisor')));
// 3. Revisor sin esa asignación no lee.
caso('3a Revisor de otro grupo consulta G1', 'NIEGA', () => getDocs(porRol(rev2, G1, J_MORNING, 'revisor')));
caso('3b Revisor de otro grupo lee m1_revisor por id', 'NIEGA', () => getDoc(doc(rev2, ruta(G1, J_MORNING, 'm1_revisor'))));
caso('3c Revisor de morning consulta afternoon1 del mismo grupo', 'NIEGA', () => getDocs(porRol(rev1, G1, J_AFTERNOON, 'revisor')));
caso('3d Revisor de afternoon1 consulta afternoon1', 'PERMITE', () => getDocs(porRol(rev3, G1, J_AFTERNOON, 'revisor')));
caso('3e Revisor con reviewShifts vacío', 'NIEGA', () => getDocs(porRol(revVacio, G1, J_MORNING, 'revisor')));
caso('3f Revisor sin documento en users', 'NIEGA', () => getDocs(porRol(revSinDoc, G1, J_MORNING, 'revisor')));
caso('3g Cuenta asignada pero sin claim reviewRole', 'NIEGA', () => getDocs(porRol(sinRol, G1, J_MORNING, 'revisor')));
caso('3h Revisor asignado: consulta de grupo de colecciones', 'NIEGA', () => getDocs(query(collectionGroup(rev1, 'registros'), where('rol', '==', 'revisor'))));
// 4. Admin sigue como hoy.
caso('4a Admin: consulta de grupo por fechaJornada (Resumen)', 'PERMITE', () => getDocs(delDia(admin)));
caso('4b Admin: consulta de grupo por fechaJornada y rol (Coincidencias)', 'PERMITE', () => getDocs(query(collectionGroup(admin, 'registros'), where('fechaJornada', '==', '2026-10-04'), where('rol', '==', 'revisor'))));
caso('4c Admin lee m1_sumador por id', 'PERMITE', () => getDoc(doc(admin, ruta(G1, J_MORNING, 'm1_sumador'))));
caso('4d SuperAdmin: consulta de grupo por fechaJornada', 'PERMITE', () => getDocs(delDia(superAdmin)));
caso('4e Admin escribe un registro', 'NIEGA', () => setDoc(doc(admin, ruta(G1, J_MORNING, 'm9_revisor')), registro('m9', 'revisor', G1, 'morning', 1791100000009)));
// 5. Sin sesión.
caso('5a Sin sesión consulta rol==revisor', 'NIEGA', () => getDocs(porRol(anon, G1, J_MORNING, 'revisor')));
caso('5b Sin sesión lee m1_revisor por id', 'NIEGA', () => getDoc(doc(anon, ruta(G1, J_MORNING, 'm1_revisor'))));
caso('5c Sin sesión: consulta de grupo', 'NIEGA', () => getDocs(delDia(anon)));
// 6. Escritura sin cambios.
caso('6a Revisor asignado crea un registro válido', 'PERMITE', () => setDoc(doc(rev1, ruta(G1, J_MORNING, 'm9_revisor')), registro('m9', 'revisor', G1, 'morning', 1791100000009)));
caso('6b Sumador crea un registro con rol revisor', 'NIEGA', () => setDoc(doc(sum1, ruta(G1, J_MORNING, 'm9_revisor')), registro('m9', 'revisor', G1, 'morning', 1791100000009)));
caso('6c Revisor NO asignado crea un registro válido (riesgo conocido)', 'PERMITE', () => setDoc(doc(rev2, ruta(G1, J_MORNING, 'm9_revisor')), registro('m9', 'revisor', G1, 'morning', 1791100000009)));
caso('6d Revisor borra un registro', 'NIEGA', async () => {
  const { deleteDoc } = await import('firebase/firestore');
  return deleteDoc(doc(rev1, ruta(G1, J_MORNING, 'm1_revisor')));
});
// 7. Otras colecciones sin cambios.
caso('7a Revisor lee jornadas/manana', 'PERMITE', () => getDoc(doc(rev1, 'jornadas/manana')));
caso('7b Revisor lee su documento users/rev1', 'PERMITE', () => getDoc(doc(rev1, 'users/rev1')));
caso('7c Revisor lee users/sum1', 'NIEGA', () => getDoc(doc(rev1, 'users/sum1')));

let fallos = 0;
for (const { nombre, esperado, fn } of casos) {
  let resultado, detalle = '';
  try {
    if (esperado === 'PERMITE') {
      const r = await assertSucceeds(fn());
      resultado = 'PERMITE';
      if (r && typeof r.size === 'number') detalle = ` (${r.size} docs)`;
      if (r && typeof r.exists === 'function') detalle = r.exists() ? ' (existe)' : ' (no existe)';
    } else {
      await assertFails(fn());
      resultado = 'NIEGA';
    }
  } catch (e) {
    resultado = esperado === 'PERMITE' ? 'NIEGA' : 'PERMITE';
    detalle = ` <- ${String(e.message).split('\n')[0].slice(0, 140)}`;
  }
  const ok = resultado === esperado;
  if (!ok) fallos++;
  console.log(`${ok ? 'OK   ' : 'FALLA'} ${nombre}: esperado ${esperado}, obtuvo ${resultado}${detalle}`);
}
console.log(`\n${casos.length - fallos}/${casos.length} casos como se esperaba`);
await env.cleanup();
process.exit(fallos ? 1 : 0);
