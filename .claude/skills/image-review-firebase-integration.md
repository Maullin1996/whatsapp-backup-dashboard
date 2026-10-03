---
name: image-review-firebase-integration
description: >
  Integración con Firebase del feature de revisión de imágenes de
  whatsapp_monitor_viewer: la Cloud Function que arroja números
  ganadores y la coincidencia contra los números que registró el
  Revisor (con redirección a la imagen exacta), y la nueva fuente de
  jornadas que viene de **otro proyecto de Firebase** (reemplazando el
  enum local `Shift`). Por ahora, jornadas y números ganadores van
  mockeados/locales para pruebas, antes de conectar Firebase de
  verdad — no asumas que ya están conectados. Consulta esta skill
  SIEMPRE que se trabaje en: la Cloud Function de números ganadores,
  cualquier lógica de coincidencia/match de números, la pantalla de
  resumen donde aparecen las coincidencias, la fuente de datos de
  jornadas (`lib/core/time/shifts.dart` o su reemplazo), o cualquier
  llamada nueva a Cloud Functions/Firestore de este feature. Requiere
  haber leído primero `image-review-domain` (vocabulario, el modelo
  `Message`, y por qué se descartó `shiftImageIndex` como señal de
  cierre de jornada).
---

# Integración con Firebase: números ganadores y jornadas externas

Esta skill cubre **la conexión con servicios externos de Firebase**
para este feature — no el modelo de negocio (`image-review-domain`),
ni los roles (`image-review-roles`), ni el guardado local
(`image-review-offline-sync`).

## Fase actual

**Actualización (paso 7, pieza c)**: Coincidencias ya lee datos REALES de
Firestore (`FirestoreMatchesRepository`, ver "Coincidencias real" más
abajo). **Desde el 2026-10-03** la función puente está desplegada y escribe
`winning_numbers` cada hora (ver "Función puente de ganadores (pieza b)").
Lo que sigue en esta sección es el antecedente (todo mockeado).

### Antecedente: todo mockeado, no conectado de verdad

**Confirmado explícitamente por el usuario**: por ahora, tanto las
**jornadas** como los **números ganadores** van con datos **locales/de
prueba**, para poder desarrollar y probar el resto del feature sin
depender de que la integración real con Firebase ya exista. El usuario
confirmó además que se sigue trabajando con el enum `Shift` local tal
como está hoy hasta que se tenga acceso al proyecto externo — recién
ahí se revisa cómo llegan las jornadas reales y se ajusta el modelo. No
asumas que hay una Cloud Function real de números ganadores ni un
proyecto de Firebase externo ya accesible — esta skill describe **hacia
dónde va** la integración, pero la implementación empieza con mocks.

**Regla de trabajo explícita del usuario**: ninguna escritura real a
Firestore/Cloud Functions de este feature se activa hasta que el
usuario lo autorice — ni siquiera cuando el resto ya esté probado con
mocks. Mientras tanto, cualquier punto que "subiría" o "llamaría" a
Firebase de verdad se implementa **imprimiendo en consola** los datos
que se enviarían, para poder probar el flujo sin tocar la base de datos
real (ver también `image-review-offline-sync`, misma regla).

Al implementar, dejar el punto de conexión bien aislado (un
`DataSource`/`Repository` con una interfaz clara) para que cambiar de
mock a la integración real después sea un solo archivo nuevo, no un
refactor grande — coherente con la Clean Architecture del proyecto.

## Números ganadores

- **Qué hace**: una **Cloud Function puente** (ver "Jornadas desde otro
  proyecto") **recibe** los números ganadores desde la fuente externa y
  los **guarda en Firestore** (del proyecto `whatsapp-pro-3d483`). No es
  una consulta on-demand cada vez que se necesita — se reciben y se
  persisten, y de ahí se comparan contra **los números que registró el
  Revisor** (nunca contra datos del Sumador — ver `image-review-domain`,
  regla 7).
- **Acceso**: la pantalla es solo para `isAdmin`/`isSuperAdmin`
  (`canViewMatches`, `features/matches/domain/helpers/`), compartida
  entre el guard de `router.dart` (vía `lib/app/auth_redirect.dart`) y
  la entrada "Coincidencias" del menú de `ChatList` — independiente de
  `reviewRole`/`reviewShifts` (esos gobiernan el formulario de captura,
  no esta pantalla) y sin filtro por `allowedGroups` (coherente con el
  punto siguiente: mira todos los grupos, no solo los asignados al
  usuario).
- **Agrupación de la visualización — siempre por jornada**: nunca existe
  un total combinado de varias jornadas en un mismo día, coherente con la
  reconciliación (`image-review-domain`, regla 3-4) y los reportes (regla
  5). **La comparación, en cambio, es del día (DECIDIDO, pieza c)**: los
  ganadores de una fecha se comparan contra los números del Revisor de
  TODAS las jornadas y grupos de esa fecha (solo cuenta el número); la
  jornada solo agrupa lo que se muestra.
- **Disparador de la comparación — HECHO (pieza c)**: se recalcula en
  cada consulta, en el cliente: la pantalla consulta **cualquier fecha a
  demanda** (selector de calendario, hoy por defecto), lee los ganadores
  de esa fecha y los registros del Revisor, y cruza con `findMatches`. No
  está ligada a la subida de una jornada ni a "fin de día". La función
  puente solo guarda los ganadores, no precalcula coincidencias.
- **Alcance de la búsqueda de coincidencias**: un número ganador puede
  coincidir con un registro de **cualquier grupo monitoreado**, no solo
  el chat que se está viendo en ese momento — así que esta comparación
  necesita mirar los registros ya subidos de todos los grupos, no ser
  una función local de una sola conversación.
- **Cómo se comparan los números — regla de 3 y 4 cifras, DECIDIDA por
  el usuario e IMPLEMENTADA** en `findMatches`
  (`features/matches/domain/helpers/`). Todo después de `trim` en ambos
  lados, sin normalizar mayúsculas ni quitar ceros a la izquierda
  (coherente con cómo el Revisor anota el número, `image-review-domain`
  regla 6) y sin validar que sean cifras (no está decidido):
  - un boleto de 4 cifras coincide si es igual a un ganador de 4;
  - un boleto de 3 coincide si es igual a las últimas 3 de un ganador de
    4, o si es igual a un ganador de 3; las dos vías valen a la vez
    ("606" coincide con "606" y con "4606");
  - un ganador de 3 solo se compara con boletos de 3: un boleto de 4 nunca
    coincide con él ("0606" contra "606" no coincide);
  - un boleto o un ganador de otra longitud se ignora, sin aviso.
  Ceros a la izquierda: "0123" coincide con "0123"; "123" coincide con
  "0123" (últimas 3); "0123" no coincide con el ganador "123".
- **Qué se muestra al encontrar coincidencia**: el número que coincidió,
  el grupo (`chatJid`/nombre del grupo) al que pertenece, quién lo
  envió, la hora y la jornada. **Ya no se muestra si el mensaje fue
  editado** (`messageEdited` se quitó en la pieza c).
- **"Ver más" — corregido, NO navega al visor**: la UI construida abre
  un **diálogo de detalle propio** (`MatchDetailDialog`), no
  `ImageDetailPage` — no cambia el chat activo ni el filtro de fecha.
  Sigue vigente la idea original de no cargar la imagen completa solo
  por aparecer en la lista: dentro del diálogo, la imagen se pide
  (`imageUrlProvider`) **solo si el usuario toca "Ver imagen"**.
  **Activado (HECHO, pieza c)**: `realImageEnabled` es `true` por
  defecto y carga la imagen real desde el `storagePath` del registro (la
  bandera apagada queda solo para tests). **PENDIENTE**: no se probó
  todavía cargar una imagen real (las reglas de Storage no están en el
  repo). Los campos alcanzan para el contexto sin cargar la imagen:
  `messageId`, `chatJid`, `senderName`, `storagePath`, `shift` y
  `localTime`.
- **Pantalla dedicada, nueva** (no una sección de otra pantalla
  existente): muestra las coincidencias **por fecha**, con **el día
  actual como valor por defecto**, y un botón que despliega un
  **selector de calendario** para consultar coincidencias de otro día.
  Dentro de una fecha, las coincidencias se organizan **por jornada**
  (nunca combinadas en un solo total del día — ver confirmación
  arriba). Como los reportes son diarios y no acumulables
  (`image-review-domain`, regla 5), esta pantalla también debe
  respetar eso: cada fecha se consulta y se muestra de forma
  independiente, nunca acumulada con otras fechas.
- **Formato de la lista de ganadores — PROVISIONAL**: un documento por
  fecha, `winning_numbers/{yyyy-MM-dd}` con el campo `numbers` (lista de
  texto), definido en una sola constante (`winningNumbersSource`). Es la
  lista del DÍA: todas las jornadas de esa fecha muestran la misma.
  (`MockMatchesRepository`, sin cablear, los organizaba por fecha y
  jornada; era una decisión del mock.)
- **De dónde sale cada dato de una coincidencia (HECHO, pieza c)**: el
  número, el grupo, la jornada, el `messageId` y el `storagePath`, del
  registro del Revisor (`image_reviews/.../registros`); `senderName` y
  `localTime`, de `whatsapp_messages/{messageId}`; el nombre del grupo, de
  `group_stats/{chatJid}` (si no existe, se muestra el `chatJid`). No hace
  falta una colección aparte de coincidencias.

### Coincidencias real (paso 7, pieza c)

**HECHO**: `matchesRepositoryProvider` usa `FirestoreMatchesRepository`
(detalle en `image-review-workflow`, "Pieza (c)"). Solo admin y superAdmin
leen `image_reviews`. La regla de `winning_numbers` (lectura para
`isAdmin()`, escritura negada) está **PUBLICADA desde el 2026-10-02**
(verificado por el usuario); la copia está en `firestore.rules.draft`. El
nombre y la forma de `winning_numbers` siguen **PROVISIONALES**; la
colección existe desde el 2026-10-03 (la escribe la función puente
desplegada). Coincidencias **abrió sin error con una cuenta admin** el
2026-10-02 (verificado por el usuario) y mostró "Todavía no hay ganadores".

### Función puente de ganadores (pieza b)

**DECIDIDO por el usuario**:
- El número de `manual_lotteries` **reemplaza** al de
  `resultados_loterias` cuando es la misma lotería y la misma fecha.
- Una lotería que solo está en la manual cuenta como un número más.
- Solo importa el número: la serie se ignora.
- La función normaliza tildes y mayúsculas entre colecciones (a confirmar
  con datos reales).
- **Función programada (polling), cada hora**: consulta las dos
  colecciones de `whats-apuestas`; no es un webhook.
- **Procesa hoy y ayer, en hora de Bogotá** (la ventana de días recientes,
  porque la manual se corrige después). **Sin historial**: no se rellenan
  fechas anteriores.
- **Sin bot**: la función no depende del bot ni lo modifica.
- **Autorizado** por el usuario: trabajar en `functions/` para esta
  función y desplegarla cuando esté lista. **Desplegada el 2026-10-03**
  (ver "Pieza b2 — DESPLEGADA" más abajo).

**Pieza b1 — HECHA: la mezcla, función pura** (`functions/winningNumbers.js`,
tests en `functions/test/winningNumbers.test.js`, `npm test`). No lee ni
escribe nada, no usa Firebase y no está exportada en `index.js`.
- `mergeWinningNumbers(automaticDoc, manualList)` →
  `{ numbers, discarded }`.
- **Forma de las entradas** (vista en datos reales, pieza b1.1):
  `automaticDoc` = documento de `resultados_loterias` de la fecha con
  `resultados: [{nombreLoteria, slug, numero, serie}]` (`serie` texto o
  `null`); `manualList` = `doc.data().list` de
  `manual_lotteries/{yyyy-MM-dd}` (**un documento por fecha** con un campo
  `list`), cuyos elementos son `{lottery, slug, date, result, series}`. El
  `date` de cada elemento **no se usa**: el id del documento ya es la
  fecha. `serie`/`series` se ignoran.
- **Clave de emparejamiento — PROVISIONAL**, aislada en `lotteryKey(slug)`
  (sin cambios en b1.1): el slug en minúsculas, sin tildes y sin espacios
  sobrantes. Es el único lugar que decide si dos entradas son la misma
  lotería. Una entrada con nombre pero sin slug no se empareja: cuenta
  sola. **Hecho observado en datos reales, sin resolver**: la automática
  trae `dorado_mañana` y la manual `doramaña`; son la misma lotería (mismo
  número en 6 de 7 días) pero con esta clave no se emparejan (cuentan por
  separado; si traen el mismo número queda uno solo en `numbers`).
- Por cada clave presente en la manual cuentan TODAS sus entradas
  manuales y se ignoran las automáticas de esa clave. Una automática
  reemplazada no se evalúa (no aparece en `discarded`).
- `numbers`: textos de exactamente **3 o 4 cifras** (pieza b1.1), con
  `trim`, ceros a la izquierda conservados ("606" y "0606" son valores
  distintos), sin duplicados, en orden ascendente de texto (`sort()`; el
  mismo resultado sin importar el orden de entrada). Es la forma que
  espera Coincidencias (`numbers`, lista de texto).
- `discarded`: `{lottery, source ('automatica' | 'manual'), value,
  reason}` de lo que no es válido. Motivos: `sin-loteria` (nombre y slug
  vacíos tras `trim` o ausentes, en cualquiera de las dos fuentes; se
  descarta sin mirar el número), `no-es-texto` (p. ej. un entero, aunque
  tenga 4 cifras), `vacio` (vacío, solo espacios, `null` o ausente),
  `no-son-cifras` y `longitud-distinta` (cualquier longitud que no sea 3
  ni 4). La función solo lo devuelve; qué hacer con él no está decidido.

**Pieza b1.1 — DECIDIDO por el usuario (2026-10-02)**:
- Se aceptan ganadores de **3 o 4 cifras**. "Cash three" cuenta, y su
  ganador de 3 cifras va en el mismo `numbers`.
- Por ahora un ganador de 3 cifras se compara solo con boletos de 3
  cifras.
- **Regla de comparación de `findMatches` — decidida e IMPLEMENTADA**
  (ver "Cómo se comparan los números" arriba): un boleto de 4 cifras gana
  si es igual al ganador completo; uno de 3 gana si es igual a las
  últimas 3 cifras de un ganador de 4 o a un ganador de 3; cualquier otra
  longitud del Revisor se ignora sin aviso; si un mismo ganador acierta a
  boletos de 3 y de 4, se muestran como coincidencias separadas (son
  registros distintos).
- **Un boleto de 3 cifras puede coincidir a la vez** con un ganador de 3
  cifras (p. ej. "Cash three") y con las últimas 3 de un ganador de 4
  cifras: el boleto "606" coincide con "606" y con "4606". La app solo
  muestra coincidencias; los revisores deciden si corresponde el premio
  doble.
- Una entrada sin nombre ni slug no es válida (`sin-loteria`).
- El slug sigue como clave PROVISIONAL.
- La escritura de `winning_numbers/{fecha}` será **solo si cambió** (se
  aplica en el handler, pieza b2).
- **Si el resultado de una fecha sale vacío, el handler (pieza b2) no
  escribe nada** y deja lo que ya había. Razón del usuario: la app solo
  muestra coincidencias, y si se borran los ganadores los revisores no
  los revisan.

**Cómo agrupa `findMatches` — HECHO**: devuelve una entrada por cada
registro coincidente (cada `MatchEntry` es un número anotado por el
Revisor), no por ganador, y un registro nunca sale dos veces aunque
coincida con varios ganadores: "606" contra "606" y "4606" da una sola
entrada. `MatchEntry` solo lleva el número del boleto (`numero`), no el
ganador que coincidió; la pantalla muestra ese número y, aparte, la lista
de ganadores del día.

**Pieza b2 — DECIDIDO por el usuario (diseño del handler)**: disparador
programado **cada 60 minutos** (`timeZone: "America/Bogota"`); procesa
**hoy y ayer en hora de Bogotá**; escribe `winning_numbers/{fecha}`
**solo si cambió**; si el resultado sale **vacío no escribe nada** y deja
lo que había. Sobre `discarded`: comportamiento actual de la pieza b2: discarded solo se registra en el log; qué hacer con discarded sigue PENDIENTE (no decidido).

**Pieza b2 — HECHA: el handler programado** (código y tests con datos
falsos; desplegado después, el 2026-10-03, ver "Pieza b2 — DESPLEGADA"):
- **`functions/winningNumbersSync.js`** (no importa `firebase-admin`; todo
  llega por parámetro):
  - `syncWinningNumbers({readAutomatic, readManual, readStored,
    writeNumbers, logger, now})`. Para cada fecha de `[hoy, ayer]`
    (`bogotaDateIds(now())`, **UTC-5 fijo**, ids `yyyy-MM-dd`): lee
    `resultados_loterias/{id}` y `manual_lotteries/{id}` (un documento
    ausente = vacío), llama a `mergeWinningNumbers` (sin cambios) con el
    documento automático y `list` de la manual, registra cada `discarded`
    en el log (fecha, lotería, fuente y motivo), y entonces:
    - si `numbers` sale vacío → no escribe (`omitida-vacia`, con una línea
      de log);
    - si no, lee `winning_numbers/{id}` y compara como listas ordenadas:
      igual → `sin-cambios`; distinto o documento ausente → escribe
      (`escrita`).
  - **Escritura**: `set({ numbers })` sin merge, es decir el documento
    queda con **solo** el campo `numbers` (lista de textos), lo único que
    lee Flutter. **SUPOSICIÓN**: que el documento no necesite otros campos
    (fecha de actualización, fuente, `discarded`).
  - **Errores por fecha**: si falla cualquier lectura (o la escritura) de
    una fecha, se registra con el id de la fecha y el **tipo** de error
    (`code` o `name`, nunca el mensaje), no se escribe esa fecha
    (`error`) y se sigue con la otra; la función no lanza por una fecha.
  - Devuelve y registra al final un resumen `[{date, status}]` con
    `escrita` | `sin-cambios` | `omitida-vacia` | `error`. Etiqueta de log
    `[GANADORES]`.
  - `runWinningNumbersSync({readSecret, connect, logger, now})`: lee el
    secreto, lo parsea como JSON, pide las fuentes a `connect` y llama a
    `syncWinningNumbers`. Si el secreto falta, está vacío, `value()` lanza
    o no es JSON válido, o `connect` falla: registra el error con el
    **nombre** del secreto (nunca su contenido) y termina sin escribir.
  - `firestoreSources(sourceDb, targetDb)`: las cuatro operaciones sobre
    dos instancias de Firestore ya creadas.
  - Constantes: `WHATS_APUESTAS_SECRET_NAME = "WHATS_APUESTAS_KEY"`
    (**PROVISIONAL**, una sola constante), `WHATS_APUESTAS_APP_NAME =
    "whats-apuestas"`, `COLLECTIONS`.
- **Disparador en `functions/index.js`** (solo se agregaron los imports y
  el export; los callables no cambiaron): `exports.syncWinningNumbers =
  onSchedule({schedule: "every 60 minutes", timeZone: "America/Bogota",
  secrets: [whatsApuestasKey]}, ...)`, sin región (igual que las demás),
  con `whatsApuestasKey = defineSecret(WHATS_APUESTAS_SECRET_NAME)`. El
  wrapper lee `whatsApuestasKey.value()`, crea (o reutiliza, si la
  instancia ya la tiene) una segunda app de Admin con nombre propio
  (`admin.initializeApp({credential: admin.credential.cert(json)},
  "whats-apuestas")`) para leer las dos colecciones, usa la app por
  defecto para `winning_numbers` y llama a `runWinningNumbersSync`.
- **Verificado en el paquete instalado** (`firebase-functions` 7.4.0,
  `firebase-admin` 13.8.0): `ScheduleOptions` tiene `schedule: string`
  (crontab o sintaxis App Engine) y `timeZone?`; `secrets?` es una opción
  de `GlobalOptions` que hereda; `SecretParam.value()` devuelve el texto
  en tiempo de ejecución; cargando `index.js` en local, el endpoint queda
  con `scheduleTrigger: {schedule: "every 60 minutes", timeZone:
  "America/Bogota"}`, `secretEnvironmentVariables: [{key:
  "WHATS_APUESTAS_KEY"}]` y sin región. Que Cloud Scheduler acepte
  `"every 60 minutes"` era SUPOSICIÓN: quedó **CONFIRMADO** con el deploy
  del 2026-10-03.
- Tests en `functions/test/winningNumbersSync.test.js` (`node:test`, datos
  falsos, `mergeWinningNumbers` real).

**Pieza b2 — DESPLEGADA y corriendo (HECHO, verificado por el usuario el
2026-10-03)**:
- **Secreto**: `WHATS_APUESTAS_KEY` creado en `whatsapp-pro-3d483`
  (versión 1).
- **Deploy**: `firebase deploy --only functions:syncWinningNumbers` (solo
  esa función, sin `--force`), alrededor de las 00:39 de Bogotá del
  2026-10-03. Resultado del CLI: `syncWinningNumbers` creada como función
  v2 programada, `us-central1`, 256 MB, `nodejs24`. El CLI habilitó Cloud
  Scheduler y dio acceso al secreto a la cuenta de servicio de Compute por
  defecto. Los 10 callables no se redesplegaron y `functions:list` los
  muestra intactos; `setReviewAssignment` no aparece, o sea que ya no está
  en producción.
- **Primera corrida** (forzada desde Cloud Scheduler a las 00:44 de
  Bogotá): resumen `escrita` para 2026-10-03 y 2026-10-02, sin errores.
  Quedó comprobado que la llave lee el ERP y que la función escribe
  `winning_numbers` (la colección ya existe). Formato en Firestore, el
  esperado: `numbers` es una lista de textos con ceros a la izquierda,
  "606" (3 cifras) incluido, en orden de texto. La entrada manual vacía del
  2026-10-02 se descartó con `sin-loteria` y no se publicó.
- **El cron corre solo**: corridas sin forzar a las 02:44, 03:44 y 04:44 de
  Bogotá, todas `sin-cambios` en las dos fechas. Queda **CONFIRMADO** que
  Cloud Scheduler acepta `"every 60 minutes"` (antes era SUPOSICIÓN). El
  aviso `[GANADORES] descartado ... sin-loteria` se repite en cada corrida
  mientras exista esa entrada manual vacía: es esperado y no afecta nada.

**DECIDIDO por el usuario — plazo de los resultados**: los resultados del
día D valen hasta las 5:30 a.m. (hora de Bogotá) del día D+1; desde esa
hora cuentan para el día nuevo. La función no cambia por esto (procesa hoy
y ayer en cada corrida) y no se agrega ninguna regla de horas.

**OBSERVADO (HECHO, sin explicar la causa)** — lecturas únicas de solo
lectura de `whats-apuestas` del 2026-10-03:
- `resultados_loterias/2026-10-03` tiene `updatedAt` del 2026-10-02 a las
  20:30 de Bogotá, con 20 entradas: las 9 de `resultados_loterias/2026-10-02`
  más 11 nuevas, entre ellas loterías de noche.
- `resultados_loterias/2026-10-02` quedó con `updatedAt` a las 13:30 de
  Bogotá y 9 entradas.
- `manual_lotteries/2026-10-03` no existe.
- Por eso `winning_numbers/2026-10-03` contiene hoy resultados del
  2026-10-02, y `winning_numbers/2026-10-02` solo tiene los 9 de las 13:30.
- "Play four día" figuraba como 5362 en una lectura anterior y como 9252
  después, sin explicación (según el usuario la API "a veces se equivoca";
  no verificado).
- **SUPOSICIÓN** (nadie la verificó): que quien escribe
  `resultados_loterias` arma el id con la fecha en UTC.

**PENDIENTE (no decidido)**:
- Confirmar con datos reales la clave de emparejamiento (`lotteryKey`):
  ver los casos `dorado_mañana` / `doramaña` y `dorado_tarde` /
  `doradotarde`.
- Qué hacer con `discarded` (hoy solo se registra en el log).
- Ver cómo evoluciona `resultados_loterias/2026-10-03` durante el día (si
  los números de ayer se reemplazan por los de hoy o se arrastran), con
  una lectura de solo lectura pasado el mediodía de Bogotá. Hasta entonces
  no se cambia la función.
- El índice de grupo de colecciones sobre `fechaJornada` y `rol` (el enlace
  sale del error de la primera consulta con ganadores, en el log
  `[COINCIDENCIAS] falló (firestore): ...`).
- Caché de Coincidencias y costo en lecturas.
- Probar "Ver imagen" con una imagen real.
- Borrar los mocks y el uploader simulado.
- Borrar los 4 documentos de prueba antes de desplegar el hosting.

## Jornadas desde otro proyecto de Firebase

### Tabla definitiva (2026-09-30)

**HECHOS** (verificados el 2026-09-30 con una lectura única y de solo
lectura de la colección `jornadas` del proyecto `whats-apuestas`, base
`(default)`):
- 5 documentos: `festivos`, `manana`, `noche`, `tarde_1`, `tarde_2`, sin
  subcolecciones. Los ids son distintos de las claves del enum `Shift`.
- Cada uno tiene exactamente 7 campos: `name`, `startTime`, `endTime`,
  `pendingApproval`, `proposedBy`, `proposedStartTime`, `proposedEndTime`.
- `startTime`/`endTime` son **texto** `yyyy-MM-ddTHH:mm:ss.000`, sin zona
  horaria (no `Timestamp`). `pendingApproval` es booleano (`false` en los
  5); los tres `proposed*` venían en `null`.
- Un documento por jornada con el horario vigente, sin historial. La fecha
  (parte `yyyy-MM-dd`) varía entre documentos.
- Sin campo de día de la semana ni lista de festivos: solo el documento
  `festivos` ("Domingos y Festivos").
- Horarios: Mañana 05:30–10:51, Tarde1 10:58–13:55, Tarde2 14:01–15:20,
  Noche 15:28–22:15, Domingos y Festivos 06:00–19:15. Una sola "Noche".

**SUPOSICIONES** (no verificadas): la hora es de pared de Colombia
(America/Bogotá; el formato coincide con `toIso8601String()` de un
`DateTime` local de Dart); solo importa la hora, la fecha sería la de la
última edición; `pendingApproval`/`proposedBy`/`proposedStartTime`/
`proposedEndTime` serían un flujo de propuesta y aprobación de cambios de
horario (mientras `pendingApproval` sea `true` rigen `startTime`/`endTime`).

**DECIDIDO** por el usuario (2026-09-30):
- Ese horario es el DEFINITIVO. La app usa una **tabla fija en código**
  (`lib/core/time/shifts.dart`), **sin lectura dinámica** de `jornadas`:
  reemplaza, para las jornadas, la meta de leerlas del otro proyecto
  (sección de abajo, que queda como antecedente).
- **Tabla ÚNICA (paso 7, pieza e)**: rige en toda la app, para todas las
  fechas y todos los mensajes; la tabla vieja y el corte
  (`newShiftsEffectiveFromMs`) se retiraron. Fin INCLUSIVO, último minuto
  completo; se trunca al minuto: `morning` 05:30–10:51, `afternoon1`
  10:58–13:55, `afternoon2` 14:01–15:20, `night1` 15:28–22:15, `holiday`
  06:00–19:15 (solo domingos, como hoy). Todo lo demás es `outOfShift`.
- **night2** queda solo como valor del enum y en etiquetas legacy;
  `getCurrentShift` nunca lo devuelve.
- Las claves del enum NO cambian (no cambian ids de `shift_image_counts`,
  de `reviewShifts` ni de la ruta de subida).
- `shiftNames` tiene las etiquetas ACTUALES; las viejas están en
  `legacyShiftNames` (solo para reconocer lo ya guardado). Detalle en
  `image-review-domain` ("Jornadas: una sola tabla").
- Los huecos entre jornadas (10:52–10:57, 13:56–14:00, 15:21–15:27) **se
  ven en el visor** agrupados junto a su jornada ("Fuera de jornada
  Mañana/Tarde 1/Tarde 2") pero **no cuentan para reportes** (son
  `outOfShift`).
- El bot debe seguir clasificando los huecos como `out_of_shift` y solo
  cambiar sus rangos y retirar night2; los bordes del bot se verifican en
  su propio repo.

**PENDIENTE** (no decidido):
- Actualizar el BOT con los mismos rangos y sin night2 (en su repo). Hasta
  entonces los contadores de `shift_image_counts` siguen la tabla vieja y
  el "imágenes en la jornada" del Resumen puede estar desfasado en los
  bordes.
- Retirar night2 de `ASSIGNABLE_SHIFTS` en `functions/` (el cliente ya no
  la ofrece, el servidor todavía la acepta).
- Fuente de festivos (hoy solo se detectan domingos).
- El horario del ERP (`jornadas` de `whats-apuestas`) puede cambiar sin
  aviso: la tabla está fija en código.
- Caché de la PWA tras desplegar (versiones viejas con la tabla vieja).
- Consecuencia a tener presente: los mensajes ya guardados se reclasifican
  con la tabla única (su etiqueta del visor se calcula al cargarlos).
- Mecanismo de recepción de números ganadores y contrato de la Cloud
  Function puente (ver "Zona gris" al final).

### Antecedente: la idea de leer las jornadas del otro proyecto

- **Antes** (hasta la tabla definitiva): las jornadas eran un enum local y
  fijo, `lib/core/time/shifts.dart` (`Shift`: mañana 06:00–10:54, tarde 1
  10:55–13:58, tarde 2 13:59–15:23, noche 1 15:24–22:24, noche 2
  22:25–22:30, domingo/festivo 06:00–19:20, fuera de jornada) — la tabla
  VIEJA, ya retirada (sus etiquetas quedan en `legacyShiftNames`). Cada mensaje se clasifica en una jornada al mapearse a
  dominio.
- **Meta original** (superada para las jornadas por la tabla fija de
  arriba): reemplazar esos rangos fijos por datos que vienen de **otro
  proyecto de Firebase** — es decir, no una colección nueva dentro del
  mismo proyecto `whatsapp-pro-3d483`, sino un **proyecto de Firebase
  distinto**, con su propio `projectId`/credenciales. **Decisión
  confirmada**: se usa una **Cloud Function puente** en
  `whatsapp-pro-3d483` que llama al otro proyecto con sus propias
  credenciales de servidor (no una segunda instancia de Firebase en el
  cliente Flutter). Esta misma Cloud Function puente es la que también
  recibe los números ganadores (ver sección anterior) — probablemente
  conviene pensarlas como el mismo componente de integración, con dos
  responsabilidades (jornadas + números ganadores), no dos funciones
  totalmente aisladas.
- **Estructura de las jornadas**: el usuario confirma que son
  **similares a las que ya existen hoy** (los mismos rangos tipo
  mañana/tarde/noche), pero con una diferencia importante: **los
  domingos manejan menos jornadas** (un conjunto reducido, distinto al
  de un día normal). Esto significa que el modelo de jornadas **no
  puede ser un set fijo de N valores válido para todos los días** — el
  conjunto de jornadas válidas depende del tipo de día (normal vs.
  domingo/festivo). El enum local actual ya intuía esto con un valor
  especial "domingo/festivo", pero ahí era una jornada más dentro del
  mismo enum; con datos externos, probablemente el modelo correcto es
  "lista de jornadas vigentes para tal fecha", no un enum fijo.
- **Parametrizar lo que ya existe**: la lógica que clasifica un mensaje
  en una jornada (`toDomain`, hoy contra el enum fijo) debe pasar a
  recibir los rangos de jornada como datos externos, no hardcodeados.
  Esto toca varios puntos ya existentes del código (no solo agregar
  algo nuevo): `shiftStatsProvider`, los conteos de `ChatDrawer`, y
  cualquier lugar que hoy asuma que `Shift` es un enum Dart fijo con
  7 valores conocidos en tiempo de compilación.
- **Riesgo a tener presente**: si las jornadas dejan de ser un enum fijo
  y pasan a ser datos dinámicos, cualquier código que haga
  `switch (shift)` exhaustivo sobre el enum `Shift` se rompe o necesita
  rediseñarse. Antes de tocar esto, mapear **todos** los usos actuales
  de `Shift` en el repo (no asumir que son solo los mencionados en
  `PROJECT_DOCUMENTATION.md`).

## Reglas técnicas heredadas del proyecto (no las reinventes)

- Toda llamada a una Cloud Function propia usa
  `FirebaseFunctions.instance.httpsCallable(name)`, igual que
  `createUser`/`setUserRole`/etc.
- Nunca lanzar excepciones desde `data`/`domain` — `Either<Failure, T>`
  siempre, con un `Failure` tipado nuevo si hace falta (o reusar
  `FirestoreFailure`/`Failure` genérico si aplica), traducido a español
  vía `mapFailureToMessage`.
- Nunca guardar URLs completas de Storage — esto ya lo cubre
  `image-review-domain`/`image-review-offline-sync`, pero aplica igual
  aquí si la Cloud Function de números ganadores llegara a devolver
  algo relacionado a imágenes.

## Zona gris / a confirmar antes de implementar

Estos puntos quedan **deferidos** — el usuario indicó que los revisamos
juntos con acceso al proyecto externo. El formato de las jornadas ya se
vio (ver "Tabla definitiva" arriba) y se decidió usar una tabla fija, así
que ese punto ya no bloquea:

- ~~**Mecanismo exacto de "recepción" de números ganadores**~~ —
  **resuelto**: polling programado cada hora, hoy y ayer en hora de Bogotá
  (ver "Función puente de ganadores (pieza b)").
- ~~Formato exacto de la lista de jornadas por fecha~~ — **resuelto**: ya
  se vio la colección `jornadas` y se decidió una tabla fija en código
  (ver "Tabla definitiva"). Queda pendiente solo cómo se marcan los
  festivos (la colección no los lista).
- Contrato completo de la Cloud Function puente (qué recibe/devuelve
  exactamente para jornadas y para números ganadores).