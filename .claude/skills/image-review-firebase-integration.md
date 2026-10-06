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
  TODAS las jornadas y grupos de esa fecha (por lotería y número: un ganador
  solo coincide con un número de la misma lotería, ver "Lotería por
  comprobante y comparación por lotería (la app)"); la jornada solo agrupa lo
  que se muestra.
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
- **Cómo se comparan los números — regla de 2, 3 y 4 cifras, DECIDIDA por
  el usuario (aclaración del cliente) e IMPLEMENTADA** en `findMatches`
  (`features/matches/domain/helpers/`). Todo después de `trim` en ambos
  lados, sin normalizar mayúsculas ni quitar ceros a la izquierda
  (coherente con cómo el Revisor anota el número, `image-review-domain`
  regla 6) y sin validar que sean cifras (no está decidido):
  - ganador de 4 cifras: un boleto de 4 coincide si es igual al ganador
    completo; uno de 3, si es igual a sus últimas 3; uno de 2, si es
    igual a sus últimas 2;
  - ganador de 3 cifras: un boleto de 3 coincide si es igual al ganador
    completo; uno de 2, si es igual a sus últimas 2;
  - un boleto de 4 nunca coincide con un ganador de 3 ("0606" contra
    "606" no coincide);
  - un boleto puede coincidir por varias vías a la vez ("606" coincide con
    "606" y con "4606");
  - un boleto de cualquier otra longitud (1, 5 o más) se ignora sin
    aviso, y un ganador de longitud distinta de 3 o 4 también.
  Ceros a la izquierda: "0123" coincide con "0123"; "123" coincide con
  "0123" (últimas 3); "0123" no coincide con el ganador "123"; "07"
  coincide con "4607" y no con "0770". La función puente no cambia por
  esta regla: los ganadores siguen siendo de 3 o 4 cifras.
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
  fecha, `winning_numbers/{yyyy-MM-dd}` con el campo `entries` (lista de
  `{loteria, numero}`, texto ambos), que es lo que lee la app; `numbers`
  (lista de texto) lo sigue escribiendo la función puente (pieza b3, aún sin
  desplegar) pero la app ya no lo lee. Definido en una sola constante (`winningNumbersSource`). Es la
  lista del DÍA: todas las jornadas de esa fecha muestran la misma.
  (`MockMatchesRepository`, ya borrado, los organizaba por fecha y
  jornada; era una decisión del mock.)
- **De dónde sale cada dato de una coincidencia (HECHO, pieza c)**: el
  número, el grupo, la jornada, el `messageId` y el `storagePath`, del
  registro del Revisor (`image_reviews/.../registros`); `senderName` y
  `localTime`, de `whatsapp_messages/{messageId}`; el nombre del grupo, de
  `group_stats/{chatJid}` (si no existe, se muestra el `chatJid`). No hace
  falta una colección aparte de coincidencias.

### Coincidencias real (paso 7, pieza c)

**HECHO**: `matchesRepositoryProvider` usa `FirestoreMatchesRepository`
(detalle en `image-review-workflow`, "Pieza (c)"); `MockMatchesRepository`
se borró (HECHO). Solo admin y superAdmin
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
  sola. **DECIDIDO por el usuario e IMPLEMENTADO — alias
  `doramaña` → `dorado_mañana`**: después de normalizar, `lotteryKey`
  aplica la tabla `LOTTERY_KEY_ALIASES` (una sola entrada: `doramana` →
  `dorado_manana`), a las entradas de las dos fuentes; así la manual
  `doramaña` reemplaza a la automática `dorado_mañana`. Respaldo: una
  lectura de solo lectura de `whats-apuestas` del 2026-10-03 en la que
  `doramaña` coincide con `dorado_mañana` en 118 fechas entre 2026-01-19 y
  2026-10-03. Se descartan los demás pares que aparecieron en esa lectura
  (`doramaña`→`antioqueñita_día`, `doradotarde`→`paisita_día`,
  `antioquenita_dia`→`dorado_mañana`, `antioqueña_dia`→`dorado_mañana`)
  porque se apoyan en una sola fecha cada uno. `doradotarde` y
  `dorado_tarde` NO se emparejaban; **superado en la pieza b3**: el usuario
  confirmó los alias `doradotarde` → `dorado_tarde`, `doradonoche` →
  `dorado_noche`, `pija0`/`pijao`/`pijo` → `pijao_de_oro` (ver "Pieza b3").
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
- **Regla de comparación de `findMatches` — reemplazada por la de 2, 3 y
  4 cifras, DECIDIDA por el usuario (aclaración del cliente) e
  IMPLEMENTADA** (ver "Cómo se comparan los números" arriba): con un
  ganador de 4, un boleto de 4 gana si es igual al ganador completo, uno
  de 3 si es igual a sus últimas 3 y uno de 2 si es igual a sus últimas
  2; con un ganador de 3, un boleto de 3 gana si es igual al ganador
  completo y uno de 2 si es igual a sus últimas 2; un boleto de 4 nunca
  coincide con un ganador de 3; boletos de otra longitud y ganadores de
  longitud distinta de 3 o 4 se ignoran sin aviso; si un mismo ganador
  acierta a boletos de distinta longitud, se muestran como coincidencias
  separadas (son registros distintos).
- **Un boleto puede coincidir a la vez** con varios ganadores: "606"
  coincide con "606" (p. ej. "Cash three") y con "4606"; "41" con "5241" y
  con "0341". La app solo muestra coincidencias; los revisores deciden si
  corresponde el premio doble.
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
    queda con **solo** el campo `numbers` (lista de textos; desde la pieza b3
    también `entries`, ver abajo), lo único que
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
- **Horas de actualización de `resultados_loterias`**: en una lectura del
  2026-10-03, 258 de 259 documentos tienen su última actualización
  (`updatedAt`) a las 13:30 de Bogotá (el otro, a las 14:00), y cada
  documento se crea a las 20:30 de Bogotá del día anterior (`createTime`).
- El documento `resultados_loterias/2026-10-03` tuvo 20 entradas a las
  20:30 del 2026-10-02, 32 a las 06:30 y 9 a las 13:30 del 2026-10-03: la
  actualización de las 13:30 **reemplaza** el contenido. (Corrige la nota
  anterior, que lo daba como un documento de 20 entradas; hoy tiene 9.)
- `resultados_loterias/2026-10-02` quedó con `updatedAt` a las 13:30 de
  Bogotá y 9 entradas.
- `manual_lotteries/2026-10-03` no existía en la primera lectura.
- Por eso, antes de las 13:30, `winning_numbers/2026-10-03` contenía
  resultados de otra jornada, y `winning_numbers/2026-10-02` solo tiene los
  9 de las 13:30.
- "Play four día" figuraba como 5362 en una lectura anterior y como 9252
  después, sin explicación (según el usuario la API "a veces se equivoca";
  no verificado).
- **SUPOSICIÓN** (nadie la verificó): que quien escribe
  `resultados_loterias` arma el id con la fecha en UTC.

**PENDIENTE (no decidido)**:
- Hasta las 13:30 de su fecha, el documento de la API trae datos de otra
  jornada, y por eso `winning_numbers` de ese día puede mostrar números que
  no son de ese día hasta esa hora. El usuario dijo que los ganadores se
  revisan al día siguiente.
- Qué hacer con `discarded` (hoy solo se registra en el log).
- El índice de grupo de colecciones sobre `fechaJornada` y `rol` (el enlace
  sale del error de la primera consulta con ganadores, en el log
  `[COINCIDENCIAS] falló (firestore): ...`).
- Caché de Coincidencias y costo en lecturas.
- Probar "Ver imagen" con una imagen real.

### Pieza b3 — cada ganador con su lotería (`entries`) — HECHA (2026-10-05, NO desplegada)

**DECIDIDO por el usuario**: cada número registrado lleva su lotería y un
ganador solo coincide con un número de la MISMA lotería (con la regla ya
implementada de 2, 3 y 4 cifras). La lista cerrada del selector (la define la
app, en otra pieza) usa como identificadores la clave normalizada de
`lotteryKey` (la tabla de abajo). Los alias, también **decididos por el
usuario**, van de la variante de la colección manual al identificador final
(sin encadenar): `doramaña` → `dorado_manana` (ya existía, 119 fechas de
coincidencia por número en una lectura de solo lectura de `whats-apuestas`
del 2026-10-05), `doradotarde` → `dorado_tarde`, `doradonoche` →
`dorado_noche` y `pija0`, `pijao` y `pijo` → `pijao_de_oro` (estos últimos
SIN prueba por número). Ningún otro alias.

**Lista cerrada: 43 identificadores y sus nombres para mostrar (sin guion
bajo)**:

| # | Identificador | Nombre para mostrar |
|---|---|---|
| 1 | `medellin` | Medellín |
| 2 | `santander` | Santander |
| 3 | `risaralda` | Risaralda |
| 4 | `dorado_manana` | Dorado mañana |
| 5 | `dorado_tarde` | Dorado tarde |
| 6 | `dorado_noche` | Dorado noche |
| 7 | `culona` | Culona |
| 8 | `culona_noche` | Culona noche |
| 9 | `astro_sol` | Astro sol |
| 10 | `astro_luna` | Astro luna |
| 11 | `pijao_de_oro` | Pijao de oro |
| 12 | `paisita_dia` | Paisita día |
| 13 | `paisita_noche` | Paisita noche |
| 14 | `chontico_dia` | Chontico día |
| 15 | `chontico_noche` | Chontico noche |
| 16 | `cafeterito_tarde` | Cafeterito tarde |
| 17 | `cafeterito_noche` | Cafeterito noche |
| 18 | `sinuano_dia` | Sinuano día |
| 19 | `sinuano_noche` | Sinuano noche |
| 20 | `cash_three_dia` | Cash three día |
| 21 | `cash_three_noche` | Cash three noche |
| 22 | `play_four_dia` | Play four día |
| 23 | `play_four_noche` | Play four noche |
| 24 | `saman_dia` | Saman día |
| 25 | `caribena_dia` | Caribeña día |
| 26 | `caribena_noche` | Caribeña noche |
| 27 | `motilon_tarde` | Motilón tarde |
| 28 | `motilon_noche` | Motilón noche |
| 29 | `fantastica_dia` | Fantástica día |
| 30 | `fantastica_noche` | Fantástica noche |
| 31 | `antioquenita_dia` | Antioqueñita día |
| 32 | `antioquenita_tarde` | Antioqueñita tarde |
| 33 | `meta` | Meta |
| 34 | `valle` | Valle |
| 35 | `manizales` | Manizales |
| 36 | `bogota` | Bogotá |
| 37 | `huila` | Huila |
| 38 | `cruz_roja` | Cruz Roja |
| 39 | `cundinamarca` | Cundinamarca |
| 40 | `cauca` | Cauca |
| 41 | `tolima` | Tolima |
| 42 | `boyaca` | Boyacá |
| 43 | `quindio` | Quindío |

**HECHO en `functions/`** (solo código y tests con datos falsos; no se tocó
`index.js`, `jornadasSync.js`, Flutter ni el bot):
- `LOTTERY_KEY_ALIASES` (`winningNumbers.js`) con los 6 alias de arriba, ya con
  las claves normalizadas por `lotteryKey`.
- `mergeWinningNumbers` devuelve además **`entries`**: `{loteria, numero}`
  de cada ganador válido, donde `loteria` es la clave de emparejamiento
  (`lotteryKey` con alias) y `numero` el valor ya validado y con `trim`. Sin
  duplicados por pareja, ordenada por `loteria` y luego por `numero`. Un mismo
  número en dos loterías da dos entradas (y `numbers` lo trae una sola vez).
  Una entrada sin slug pero con nombre cuenta en `numbers` como siempre y en
  `entries` lleva `loteria: ""` (sin más lógica para ese caso). `numbers` y
  `discarded` no cambian, y lo descartado no entra a `entries`.
- `syncWinningNumbers` escribe `set({ numbers, entries })` (un solo `set`, sin
  merge) y compara contra lo guardado **incluyendo `entries`**: los
  documentos de hoy y ayer, que hasta ahora no tienen `entries`, se reescriben
  una vez. Un resultado vacío sigue sin escribir nada; errores aislados,
  resumen y `discarded` solo al log, sin cambios. La dependencia
  `writeNumbers(dateId, numbers, entries)` recibe ahora el tercer argumento.
- Tests (`node:test`): 152 (136 anteriores + 16 nuevos). Se ajustaron 6 de los
  anteriores porque fijaban la forma de lo que se devuelve o se escribe:
  `sin nada devuelve listas vacías` (ahora incluye `entries: []`);
  `doradotarde y dorado_tarde no se emparejan` (fijaba el comportamiento SIN
  alias; con el alias confirmado se emparejan y gana la manual);
  `no escribe cuando los guardados son iguales…` (el guardado de ejemplo ahora
  trae `entries`: sin ellos se reescribe); `escribe solo el campo numbers…`
  (ahora `numbers` y `entries`); `discarded se registra y nunca se escribe`
  (las claves del documento son `numbers` y `entries`); y `firestoreSources`
  (el `set` lleva `numbers` y `entries`).
- **Verificado** con `lotteryKey` real: cada uno de los 43 identificadores
  coincide con la clave de todos los slugs reales vistos (ERP, manual y
  tests), p. ej. `fantástica_día` → `fantastica_dia`, `cash_three_día` →
  `cash_three_dia`, `medellín` → `medellin`. Sin slug real visto todavía (la
  coincidencia es SUPOSICIÓN por el patrón): `cash_three_noche`,
  `play_four_noche`, `motilon_noche`, `fantastica_noche`. En la colección
  manual hay claves que quedan FUERA de los 43 (y de los alias): p. ej.
  `super_astro_luna`, `super_astro_sol`, `cruzroja`, `cruz_r`, `astroluna`,
  `astrosol`, `saman`, `pijao_noche`, `pijao_tarde`, `culona_dia`,
  `antioquena_dia`, `carbena_dia`, `extra_colombia`, `paisita_1`: siguen con su
  propia clave.

**Forma elegida para el cambio más chico (NO es una decisión del usuario)**:
`winning_numbers/{fecha}` **conserva `numbers`** (lista de textos, como
siempre) y **suma `entries`** (lista de `{loteria, numero}`). La app ya lee
`entries` y dejó de leer `numbers` (ver abajo): hasta desplegar la función no
hay `entries` en producción. Los documentos de fechas anteriores a este cambio
no se reescriben (la función solo procesa hoy y ayer, sin historial) y no
tendrán `entries` (Coincidencias los trata como "todavía no hay ganadores").

### Lotería por comprobante y comparación por lotería (la app) — HECHA (2026-10-05, sin desplegar)

**DECIDIDO por el usuario e IMPLEMENTADO en la app (2026-10-05, sin desplegar)**: cada comprobante lleva su lotería, elegida de una lista cerrada de 43 identificadores (`lib/core/lotteries/lotteries.dart`: constante en un solo archivo, con `loteriaDisplayName(id)`, que devuelve el nombre o el mismo texto si no está en la lista) y obligatoria para los dos roles; lo que se guarda en `loteria` es el identificador; un ganador solo coincide con un número de la misma lotería; la app lee `entries` de `winning_numbers/{fecha}` y dejó de leer `numbers`.

**HECHO en la app** (solo código y tests con datos falsos; no se tocó
`functions/`, `firestore.rules.draft`, el Resumen, `edit_attempts`, `editado`,
la lógica de tiempo ni el modelo de jornadas):
- **Lista cerrada** (`lib/core/lotteries/lotteries.dart`): `lotteries` (43
  identificadores con su nombre para mostrar, los de "Pieza b3"),
  `isKnownLoteria(id)` y `loteriaDisplayName(id)`. No se lee de Firestore.
- **Formulario**: `ComprobanteCard` reemplaza el `TextField` "Lotería
  (opcional)" por un `DropdownMenu` (clave `loteria-N`) con los nombres y
  filtro al escribir; guarda el identificador en el borrador. Si el valor del
  comprobante no está en la lista (texto libre de un registro viejo), arranca
  sin selección. Error inline "Elige una lotería" tras el primer intento de
  guardar. `Comprobante.loteria` sigue siendo `String?`; `toMap`/`fromMap` y
  la forma del payload no cambian (solo que ahora se escribe un
  identificador). La vista de solo lectura muestra el nombre
  (`loteriaDisplayName`).
- **Validación**: `validateImageReviewForm` exige, por comprobante, una
  lotería de la lista (después de números y total), con
  `ImageReviewFailure.loteriaInvalida(indice)`: "Comprobante N: elige la
  lotería". **Los dos roles usan el mismo formulario y el Sumador también la
  exige.**
- **Comparación**: `WinningEntry {loteria, numero}` (entidad nueva);
  `findMatches(List<WinningEntry>, List<MatchEntry>)` solo compara dentro de la
  misma lotería, con la misma regla de 2, 3 y 4 cifras; una entrada con la
  lotería nula, vacía o fuera de la lista no coincide con nada; una entrada por
  registro. `MatchEntry` suma `loteria` (`String?`).
- **Datos de Coincidencias**: `RevisorRecord.numeros` pasó de `List<String>` a
  `List<RecordedNumber {numero, loteria}>`: `parseRevisorRecord` pone en cada
  número la lotería de su comprobante (null si falta; una `loteria` que no es
  texto es un error con el id del documento, como los demás campos).
  `WinningNumbersDatasource.fetchByFecha` devuelve `List<WinningEntry>` y lee
  **`entries`** (`winningNumbersSource.field`); un documento ausente o sin
  `entries` es lista vacía ("todavía no hay ganadores"); un `entries` mal
  formado (no es lista, o un elemento sin `loteria` o `numero` de texto) es
  `Left`. `JornadaMatches.winningNumbers` lleva los pares.
- **Pantallas**: el chip de ganadores y la tarjeta muestran "Dorado mañana ·
  1288" (`loteriaNumeroLabel`; sin lotería, solo el número); el detalle suma la
  fila "Lotería". En la variante móvil de la tarjeta el texto puede envolver (a
  360 px desbordaba 63 px con el nombre de la lotería).
- **Tests**: `flutter test` pasó de 906 a **938** en verde; los únicos fallos
  son los 2 conocidos (`message_bubble_test.dart` y `message_list_test.dart`,
  `package:web`). Nuevos: la lista (8), `findMatches` por lotería (6), el
  datasource de ganadores y de registros del Revisor, el repositorio (cada
  número hereda la lotería de su comprobante), el selector y la validación. Se
  ajustaron los que dependían de la forma anterior: ganadores como lista de
  textos (`find_matches`, repositorio, datasources, wiring, widgets de
  Coincidencias, con una lotería por defecto en ganadores y registros), la
  lotería opcional (`validate_image_review_form_test`, `review_role_test`, los
  helpers de llenado de los tests del panel y del visor, que ahora eligen una
  lotería con `pick_loteria.dart`) y el skeleton de Coincidencias (su fixture
  usa un chip con "Meta", el nombre más corto, para mantener la forma de UNA
  fila de ganadores; el skeleton no cambió).

**PENDIENTES (no decididos)**: desplegar la función y el hosting (la función primero: hasta entonces los documentos de `winning_numbers` no traen `entries` y Coincidencias dice "Todavía no hay ganadores"); los boletos viejos de texto libre (o sin lotería) no coinciden con nada; un ganador de una lotería fuera de la lista no coincide con nada; si el Revisor necesita una lotería que no está en la lista, hoy no puede guardar.

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
  (sección de abajo, que queda como antecedente). **Superado por la pieza
  2 de horarios dinámicos** (2026-10-03, ver "Lectura en la app" abajo): la
  app lee `jornadas` y `festivos_colombia` y esta tabla fija queda como
  RESPALDO.
- **Tabla ÚNICA (paso 7, pieza e)**: rige en toda la app, para todas las
  fechas y todos los mensajes; la tabla vieja y el corte
  (`newShiftsEffectiveFromMs`) se retiraron. Fin INCLUSIVO, último minuto
  completo; se trunca al minuto: `morning` 05:30–10:51, `afternoon1`
  10:58–13:55, `afternoon2` 14:01–15:20, `night1` 15:28–22:15, `holiday`
  06:00–19:15 (domingos y, desde la pieza 2, festivos). Todo lo demás es
  `outOfShift`.
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
- (Fuente de festivos y "el horario del ERP puede cambiar sin aviso", para
  la APP: resueltos por la pieza 2, ver "Lectura en la app". El bot sigue
  con su tabla vieja: pieza 3.)
- Caché de la PWA tras desplegar (versiones viejas con la tabla vieja).
- Consecuencia a tener presente: los mensajes ya guardados se reclasifican
  con la tabla única (su etiqueta del visor se calcula al cargarlos).
- Mecanismo de recepción de números ganadores y contrato de la Cloud
  Function puente (ver "Zona gris" al final).

### Réplica de jornadas (horarios dinámicos, pieza 1)

**HECHO (lectura única de solo lectura del 2026-10-03)**: `jornadas` del ERP
sigue con los mismos 5 documentos, los mismos 7 campos y los mismos horarios
de la lectura del 2026-09-30 (ver "Tabla definitiva"). La fecha de
`startTime`/`endTime` es la de `updateTime` del documento en hora de Bogotá.

**DECIDIDO por el usuario (2026-10-03)**:
- La función programada copia la colección `jornadas` del ERP a una colección
  `jornadas` de **nuestro** proyecto (nombre **PROVISIONAL**, en una sola
  constante, `JORNADAS_COLLECTIONS.target`). Es una **réplica exacta**:
  mismos ids (`festivos`, `manana`, `tarde_1`, `tarde_2`, `noche`) y los
  mismos 7 campos (`name`, `startTime`, `endTime`, `pendingApproval`,
  `proposedBy`, `proposedStartTime`, `proposedEndTime`), copiados tal cual,
  sin convertir nada. Sin historial y sin fechas de vigencia.
- Por cada documento del ERP: se compara con el nuestro y se escribe solo si
  es distinto o no existe, con `set` completo (sin merge).
- Validación mínima antes de escribir: `startTime` y `endTime` son texto
  `yyyy-MM-ddTHH:mm:ss.000` con hora (00–23) y minuto (00–59) válidos. Un
  documento inválido se omite y se registra con su id y el motivo, sin
  copiarlo y sin tocar el guardado. No se valida nada más.
- Si el ERP devuelve cero documentos, no se escribe ni se borra nada.
  **Nunca** se borra un documento de nuestra colección.
- Un fallo en un documento no frena a los demás ni a los ganadores. Ganadores
  y jornadas van cada uno en su propio try/catch; ninguno lanza al otro.
- Corre en el **mismo** disparador programado que los ganadores, después de
  ellos, con la misma conexión al ERP y el mismo secreto. No hay otro export,
  otro secreto ni otro schedule.
- **"Mañana" vale para las mañanas de todos los días excepto domingos y
  festivos, que usan `festivos`.** La lista de festivos en Firebase queda
  como pieza aparte.

**Conversión de ids del ERP a claves de la app** (enum `Shift`; la función
no convierte nada, la réplica guarda los ids del ERP):

| Id del ERP (`name`) | Clave de la app |
|---|---|
| `manana` ("Mañana") | `morning` |
| `tarde_1` ("Tarde1") | `afternoon1` |
| `tarde_2` ("Tarde2") | `afternoon2` |
| `noche` ("Noche") | `night1` |
| `festivos` ("Domingos y Festivos") | `holiday` |

`night2` y `outOfShift` no tienen documento en el ERP. La conversión sale de
comparar los horarios de cada documento con la tabla fija de
`lib/core/time/shifts.dart` (coinciden uno a uno).

**Pieza 1 — HECHA y DESPLEGADA (2026-10-03, dato del usuario)**: `syncWinningNumbers`, con la copia de `jornadas`, se desplegó el 2026-10-03; la colección `jornadas` existe en nuestro proyecto con los 5 documentos (`festivos`, `manana`, `noche`, `tarde_1`, `tarde_2`) y el log de cada corrida trae `[JORNADAS]` con el resumen. Código y tests con datos falsos:
- **`functions/jornadasSync.js`** (no importa `firebase-admin`):
  - `syncJornadas({readSourceJornadas, readStoredJornada, writeJornada,
    logger})`: lee todos los documentos del ERP; por cada uno valida, lee el
    nuestro por id y escribe si cambió o no existe. Devuelve y registra un
    resumen `[{id, status}]` con `escrito` | `sin-cambios` |
    `omitido-invalido` | `error`. Etiqueta de log `[JORNADAS]`.
  - Motivos de omisión: `startTime-no-es-texto`, `startTime-formato-invalido`,
    `startTime-hora-invalida` (y los mismos con `endTime`), `sin-datos`.
  - Errores: un documento que falla (lectura del nuestro o escritura) queda
    `error` con su id y el **tipo** de error (nunca el mensaje), y se sigue.
    Si no se puede leer el ERP: log y `null`, sin escribir. Cero documentos:
    `[]`, sin escribir ni borrar.
  - Lo que se copia es el `data()` completo del documento del ERP, tal cual.
    Hoy son los 7 campos; si el ERP agregara un campo, también se copiaría.
  - Comparación: igualdad profunda (orden de claves indiferente; un valor con
    `isEqual`, como un `Timestamp`, se compara con él).
  - `jornadasFirestoreSources(sourceDb, targetDb)`: un `get()` de la colección
    del ERP, un `get()` por id de la nuestra y `set()` sin merge. Ni `delete`,
    ni `update`, ni batches.
- **`functions/winningNumbersSync.js`**: `runWinningNumbersSync` ahora envuelve
  `syncWinningNumbers` en un try/catch (antes, si lanzaba, la promesa se
  rechazaba; ahora registra `[GANADORES] la sincronización falló` con el tipo
  y sigue) y después, si `connect` devolvió `jornadas`, llama a
  `syncJornadas` en su propio try/catch. Su firma y su valor de retorno (el
  resumen de ganadores, o `null`) no cambiaron. Si el secreto falta o
  `connect` falla, no corre ninguna de las dos.
- **`functions/index.js`**: solo el import y el `connect` del handler, que
  devuelve `{...firestoreSources(...), jornadas:
  jornadasFirestoreSources(sourceDb, firestore)}` con la misma app
  `"whats-apuestas"`.
- Costo por corrida: una consulta de 5 documentos en el ERP, 5 lecturas por id
  en nuestro proyecto y hasta 5 escrituras (0 si nada cambió), cada hora.
- Tests en `functions/test/jornadasSync.test.js` (`node:test`, datos falsos).
- **Reglas**: bloque `match /jornadas/{docId}` en `firestore.rules.draft`
  (lectura con sesión, escritura negada), **PUBLICADO** a mano por el
  usuario (confirmado el 2026-10-04).
- **Nombre**: la colección de la raíz `jornadas` es distinta de las
  subcolecciones `image_reviews/{chatJid}/jornadas`. HECHO: hoy ningún código
  hace una consulta de grupo sobre `jornadas` (que las mezclaría).

**SUPOSICIÓN**: los horarios que se usan son siempre `startTime` y `endTime`
(de ellos solo la hora).

**PENDIENTE (no decidido)**:
- ~~Pieza 2: la app lee la colección~~ — HECHA (ver "Lectura en la app").
- Pieza 3: el bot la lee.
- ~~La lista de festivos~~ — HECHA: `festivos_colombia` (ver abajo).
- Desplegar la función con este cambio.
- Qué significan `pendingApproval` y `proposed*` en el ERP.

### Festivos en Firebase: `festivos_colombia`

**HECHO (carga del 2026-10-03, verificada releyendo los documentos)**:
colección `festivos_colombia` de `whatsapp-pro-3d483` con **diez
documentos**, ids `"2026"` a `"2035"`, cada uno con un solo campo `fechas`
(lista de textos `yyyy-MM-dd`, ordenada, sin repetidas): 18 fechas por año,
salvo 2030 con 17 (el Sagrado Corazón y San Pedro y San Pablo caen los dos
el 2030-07-01 y quedó una sola). Se escribió con el Admin SDK (`set`
completo, sin merge) a partir de una lista **generada con reglas** (festivos
fijos, trasladables al lunes y de Semana Santa, Pascua gregoriana) y
**revisada por el usuario**; la copia local está en
`D:\documentos\Mauricio\festivos\` (fuera del repo). Su regla de lectura
está en `firestore.rules.draft`, **PUBLICADA** a mano por el usuario
(confirmado el 2026-10-04).

### Lectura en la app (horarios dinámicos, pieza 2)

**DECIDIDO por el usuario e IMPLEMENTADO (2026-10-03, opción A + versión
simple)**: la app lee `jornadas` y `festivos_colombia` y los usa para
clasificar. **La tabla fija actual es el respaldo.**
- **`lib/core/time/shifts.dart`**: una sola **tabla activa** en memoria
  (`ShiftTable`: rangos de día normal en orden del día, rango de `holiday`
  y el conjunto de fechas festivas `yyyy-MM-dd`), inicializada con
  `fixedShiftTable` (la tabla fija de siempre, sin festivos).
  `replaceShiftTable(table)` la reemplaza y devuelve `true` si era distinta;
  `restoreFixedShiftTable()` (`@visibleForTesting`) vuelve a la fija.
  `shiftLastMinute` ya no es una copia aparte: sale de los rangos (no se
  pueden desalinear). Las firmas de `getCurrentShift`, `shiftGapBefore`,
  `shiftViewerLabel` y `jornadaTerminada` no cambiaron y siguen síncronas.
- **`isHolidayOrSunday(DateTime)`**: domingo, o fecha de la lista de
  festivos. Un festivo entre semana se comporta **exactamente como un
  domingo** (rango de `holiday`, sin huecos de día). La usan
  `getCurrentShift`, `shiftGapBefore` (y por ellas `shiftViewerLabel`) y
  `_shiftsOfDay` de Coincidencias (`firestore_matches_repository.dart`).
  `jornadaTerminada` no compara días: recibe la jornada.
- **Etiquetas**: `shiftNames`, `legacyShiftNames` y `shiftGapLabels` siguen
  siendo texto FIJO; no se generan desde la tabla.
- **Zona horaria**: sin cambios; se usa la fecha y hora de pared del
  `DateTime` que llega.
- **Datasource** (`lib/features/shift_schedule/data/datasources/
  shift_schedule_datasource.dart`, nombres PROVISIONALES): un `.get()` de
  cada colección, sin `.snapshots()`, `Either<Failure, ShiftTable>`, nunca
  lanza (`.withReader` para tests). Arma la tabla desde la FIJA:
  - conversión de ids `manana`→`morning`, `tarde_1`→`afternoon1`,
    `tarde_2`→`afternoon2`, `noche`→`night1`, `festivos`→`holiday`;
  - solo cuentan hora y minuto de `startTime`/`endTime`
    (`yyyy-MM-ddTHH:mm:ss.000`; segundos descartados, último minuto
    incluido); `pendingApproval` y `proposed*` se ignoran;
  - un documento con hora inválida o inicio posterior al fin se ignora
    (esa jornada conserva su rango fijo); un id desconocido se ignora; una
    jornada ausente conserva la fija;
  - una fecha de festivo sin formato `yyyy-MM-dd` válido se ignora;
  - si cualquiera de las dos lecturas falla: `Left` (queda la tabla que
    había).
- **Cargador** (`shiftScheduleLoaderProvider`,
  `shift_schedule_providers.dart`): `FutureProvider` que observa
  `reviewerUidProvider`, disparado con un `ref.listen` en
  `WhatsAppMonitorApp.build` (`app.dart`: siempre montado, también con el
  visor abierto, y `ref.listen` no reconstruye la app). Sin uid: no lee ni
  registra nada. Con uid: lee **una vez por sesión** (la regla exige
  sesión), sin reintentos y sin lanzar. Falla: `[JORNADAS] falló (...)` con
  `failureLogLine` y queda la tabla que había (la fija si nunca se cargó).
  Tabla distinta de la activa: la reemplaza e invalida `shiftStatsProvider`
  (conteos de "Imágenes por jornada" de `ChatDrawer`). Igual: no hace nada.
  Nada espera al cargador (no hay timeout).
- **Tests**: `test/unit/shifts_table_test.dart`,
  `test/unit/shift_schedule/` (datasource y cargador) y dos casos nuevos en
  `firestore_matches_repository_test.dart`. Los tests de jornadas que ya
  existían pasan sin cambios con la tabla por defecto.

**Limitaciones aceptadas por el usuario**:
- Los mensajes ya cargados **mantienen su etiqueta** hasta cambiar de chat o
  de filtro: `MessagesNotifier` no se toca y `ref.invalidate` reutiliza la
  misma instancia (riverpod 3.3.2), cuyo `build` no recarga si no cambió el
  chat ni el filtro. Solo se recalculan los conteos.
- Lo guardado antes del deploy (registros locales y subidos) puede quedar
  con etiquetas desfasadas.

**PENDIENTE (no decidido)**:
- ~~Publicar a mano las reglas de `jornadas` y de `festivos_colombia`~~ —
  HECHO (confirmado por el usuario el 2026-10-04).
- El bot sigue con su tabla vieja y no lee las colecciones (pieza 3).
  **RIESGO CONOCIDO (hasta actualizar el bot)**: en cada festivo entre semana, empezando por el **lunes 2026-10-12**, la app (con la pieza 2) trata el día como domingo (solo la jornada `holiday`, 06:00–19:15; lo de fuera queda "fuera de jornada") y el bot lo clasifica como un día normal con su tabla vieja: `shift_image_counts` de ese día no coincide con lo que ve la app, y el Resumen mostrará diferencias en "imágenes en la jornada".
- El texto de las etiquetas lleva las horas escritas y no se actualiza si el
  ERP cambia un horario: defecto cosmético.
- Zona horaria del dispositivo: un festivo depende de la fecha local, así
  que un dispositivo fuera de UTC-5 podría ver otro día.
- Qué hacer si el ERP trae `pendingApproval: true` o valores en
  `proposed*` (hoy se ignoran).
- Desplegar el hosting con este cambio.

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
  (ver "Tabla definitiva"); desde la pieza 2 la app la lee, con los
  festivos de `festivos_colombia`.
- Contrato completo de la Cloud Function puente (qué recibe/devuelve
  exactamente para jornadas y para números ganadores).