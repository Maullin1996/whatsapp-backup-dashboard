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

## Fase actual: todo mockeado, no conectado de verdad

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
- **Agrupación de la comparación/visualización — CONFIRMADA, siempre
  por jornada, nunca por día**: el usuario aclaró explícitamente
  "siempre es por jornada y nunca por día" — nunca existe un total
  combinado de varias jornadas en un mismo día, coherente con que
  también la reconciliación (`image-review-domain`, regla 3-4) y los
  reportes (regla 5) son siempre por jornada y nunca combinados por
  día.
- **Disparador de la comparación — NO DEFINIDO (PENDIENTE)**: la
  pantalla construida (`/matches`, datos inventados) consulta
  **cualquier fecha a demanda** (selector de calendario, hoy por
  defecto) y no está ligada a la subida de una jornada
  (`image-review-offline-sync`) ni a "fin de día". Qué momento/lectura
  alimentará los registros reales de coincidencias sigue sin resolver:
  ¿se recalcula en cada consulta contra Firestore, o la Cloud Function
  puente precalcula y guarda coincidencias al recibir números
  ganadores? — pendiente.
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
  envió, la hora, la jornada y si el mensaje de WhatsApp fue editado.
- **"Ver más" — corregido, NO navega al visor**: la UI construida abre
  un **diálogo de detalle propio** (`MatchDetailDialog`), no
  `ImageDetailPage` — no cambia el chat activo ni el filtro de fecha.
  Sigue vigente la idea original de no cargar la imagen completa solo
  por aparecer en la lista: dentro del diálogo, la imagen se pide
  (`imageUrlProvider`) **solo si el usuario toca "Ver imagen"**, y con
  los datos de prueba de hoy ese pedido está apagado por una bandera
  (`realImageEnabled`, `false` por defecto): tocar "Ver imagen" muestra
  un aviso, sin tocar la red ni construir ningún `ExtendedImage`. Los
  campos ya guardados alcanzan para el contexto sin cargar la imagen:
  `id`/`messageId`, `chatJid`, `senderName`, `storagePath`, `shift`,
  `localTime` y si el mensaje fue editado.
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
- **Formato de la lista de ganadores — decisión del mock, no del
  contrato real**: `MockMatchesRepository` (datos inventados) organiza
  los números ganadores por (fecha, jornada), coherente con el punto
  anterior — pero es una decisión de cómo se armó el mock, no un
  contrato confirmado de la fuente externa; el formato real sigue
  diferido (ver "Zona gris" más abajo).
- **PENDIENTE: estructura de la colección real de números/coincidencias
  no definida**. Al conectar (paso 7) va a hacer falta una colección
  nueva con los registros de números — hoy `ImageReviewRecord`
  (`features/image_review/domain/entities/`) no trae `senderName`,
  `groupName`, `localTime` ni el `isEdited` del mensaje de WhatsApp (los
  campos que hoy arma `MatchEntry` para la UI); de dónde sale cada uno
  de esos datos en el contrato real (¿del propio `Message`? ¿de una
  colección aparte?) queda diferido a ese paso.

## Jornadas desde otro proyecto de Firebase

- **Hoy**: las jornadas son un enum local y fijo,
  `lib/core/time/shifts.dart` (`Shift`: mañana 06:00–10:54, tarde 1
  10:55–13:58, tarde 2 13:59–15:23, noche 1 15:24–22:24, noche 2
  22:25–22:30, domingo/festivo 06:00–19:20, fuera de jornada). Cada
  mensaje se clasifica en una jornada al mapearse a dominio.
- **Meta**: reemplazar esos rangos fijos por datos que vienen de **otro
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

Estos tres puntos quedan **deferidos hasta tener acceso al proyecto
externo de Firebase** — el usuario indicó que los revisamos juntos en
ese momento, no hay forma de resolverlos por conversación ahora mismo:

- **Mecanismo exacto de "recepción" de números ganadores**: ¿es un
  endpoint HTTP al que algo externo hace push (webhook), o la Cloud
  Function puente consulta activamente al otro proyecto (polling
  programado)? Cambia bastante el diseño (trigger HTTP vs. Cloud
  Scheduler).
- **Formato exacto de la lista de jornadas por fecha** que devuelve el
  proyecto externo (nombres, horarios, cómo se marca cuáles aplican un
  domingo vs. un día normal) — sin verlo no se puede diseñar el modelo
  final que reemplace el enum `Shift`.
- Contrato completo de la Cloud Function puente (qué recibe/devuelve
  exactamente para jornadas y para números ganadores).