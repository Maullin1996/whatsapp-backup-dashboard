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
abajo). Los números ganadores todavía no llegan: la colección
`winning_numbers` no existe hasta que se implemente la función puente. Lo
que sigue en esta sección es el antecedente (todo mockeado).

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
- **Cómo se comparan los números**: igualdad exacta de `String` después
  de `trim` en ambos lados, sin normalizar mayúsculas ni quitar ceros a
  la izquierda (coherente con cómo el Revisor anota el número,
  `image-review-domain` regla 6: `String`, con `trim`, conservando
  ceros a la izquierda) — "0123" y "123" nunca coinciden entre sí.
  Implementado en `findMatches` (`features/matches/domain/helpers/`).
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
(verificado por el usuario); la copia está en `firestore.rules.draft`, cuyo
encabezado todavía la da como no publicada. El nombre y la forma de
`winning_numbers` siguen **PROVISIONALES** y la colección **todavía no
existe**. Coincidencias **abrió sin error con una cuenta admin** el
2026-10-02 (verificado por el usuario) y mostró "Todavía no hay ganadores".

**DECIDIDO por el usuario — regla de la función puente (pieza b), NO
implementada**:
- El número de `manual_lotteries` **reemplaza** al de
  `resultados_loterias` cuando es la misma lotería y la misma fecha.
- Una lotería que solo está en la manual cuenta como un número más.
- La función normaliza tildes y mayúsculas entre colecciones (a confirmar
  con datos reales).
- Relee una ventana de días recientes, porque la manual se corrige
  después.

**PENDIENTE (no decidido)**:
- La función puente (toca `functions/`; necesita autorización aparte).
- El índice de grupo de colecciones sobre `fechaJornada` y `rol` (el enlace
  sale del error de la primera consulta con ganadores, en el log
  `[COINCIDENCIAS] falló (firestore): ...`).
- Caché de Coincidencias y costo en lecturas.
- Probar "Ver imagen" con una imagen real.
- Borrar los mocks y el uploader simulado.
- Borrar los 4 documentos de prueba antes de desplegar el hosting.
- Corregir el encabezado de `firestore.rules.draft` (dice que el bloque de
  `winning_numbers` no está publicado).

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
  (sección de abajo, que queda como antecedente). Rige en toda la app desde
  el despliegue; el usuario solo despliega con todas las jornadas cerradas.
- Tabla nueva (fin INCLUSIVO, último minuto completo; se trunca al
  minuto): `morning` 05:30–10:51, `afternoon1` 10:58–13:55, `afternoon2`
  14:01–15:20, `night1` 15:28–22:15, `holiday` 06:00–19:15 (solo domingos,
  como hoy). Todo lo demás es `outOfShift`. **night2 no existe en la tabla
  nueva**; se conserva en el enum solo por la tabla vieja y sus etiquetas.
- Las claves del enum NO cambian (no cambian ids de `shift_image_counts`,
  de `reviewShifts` ni de la ruta de subida).
- Tabla vieja y nueva coexisten; el corte es `newShiftsEffectiveFromMs`
  (ms UTC, hoy `null` = tabla vieja en toda la app). Lo ya guardado se queda
  tal cual. Detalle de la regla en `image-review-domain` ("Jornadas: tabla
  vieja, tabla nueva y corte").
- Los huecos entre jornadas (10:52–10:57, 13:56–14:00, 15:21–15:27) **se
  ven en el visor** agrupados junto a su jornada ("Fuera de jornada
  Mañana/Tarde 1/Tarde 2") pero **no cuentan para reportes** (son
  `outOfShift`).
- El bot debe seguir clasificando los huecos como `out_of_shift` y solo
  cambiar sus rangos y retirar night2; los bordes del bot se verifican en
  su propio repo.

**PENDIENTE** (no decidido):
- Fecha fija del corte y despliegue coordinado con el bot.
- Actualizar el bot (rangos y claves de `shift_image_counts`) en su repo.
- Retirar night2 de `ASSIGNABLE_SHIFTS` en `functions/` (el cliente ya no
  la ofrece con la tabla nueva, pero el servidor todavía la acepta).
- Fuente de festivos (hoy solo se detectan domingos).
- Caché de la PWA tras el despliegue (versiones viejas con la tabla vieja).
- Mecanismo de recepción de números ganadores y contrato de la Cloud
  Function puente (ver "Zona gris" al final).

### Antecedente: la idea de leer las jornadas del otro proyecto

- **Antes** (hasta la tabla definitiva): las jornadas eran un enum local y
  fijo, `lib/core/time/shifts.dart` (`Shift`: mañana 06:00–10:54, tarde 1
  10:55–13:58, tarde 2 13:59–15:23, noche 1 15:24–22:24, noche 2
  22:25–22:30, domingo/festivo 06:00–19:20, fuera de jornada) — hoy es la
  tabla VIEJA. Cada mensaje se clasifica en una jornada al mapearse a
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

- **Mecanismo exacto de "recepción" de números ganadores**: ¿es un
  endpoint HTTP al que algo externo hace push (webhook), o la Cloud
  Function puente consulta activamente al otro proyecto (polling
  programado)? Cambia bastante el diseño (trigger HTTP vs. Cloud
  Scheduler).
- ~~Formato exacto de la lista de jornadas por fecha~~ — **resuelto**: ya
  se vio la colección `jornadas` y se decidió una tabla fija en código
  (ver "Tabla definitiva"). Queda pendiente solo cómo se marcan los
  festivos (la colección no los lista).
- Contrato completo de la Cloud Function puente (qué recibe/devuelve
  exactamente para jornadas y para números ganadores).