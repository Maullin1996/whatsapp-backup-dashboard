---
name: image-review-roles
description: >
  Reglas de roles y permisos del feature de revisión de imágenes de
  whatsapp_monitor_viewer: los roles Revisor y Sumador, cómo se activan
  (solo desde AdminPage, solo por el superAdmin), cómo conviven con
  admin/superAdmin (custom claims booleanos independientes), la
  asignación obligatoria de un grupo y una jornada específicos a cada
  Revisor/Sumador (únicos por rol, nunca dos personas del mismo rol
  comparten grupo+jornada), la restricción de que el formulario de
  captura en image_detail_page es exclusivo de tablet/PC (nunca
  mobile), y el bloqueo de navegación (en ambos sentidos) mientras la
  imagen actual no tenga registro guardado. Consulta esta skill SIEMPRE que se trabaje
  en: el sistema de autenticación/roles (AuthenticatedUser, custom
  claims, AdminPage, Cloud Functions de gestión de usuarios), el
  formulario de captura de image_detail_page, o cualquier
  guard/permiso relacionado con Revisor o Sumador — aunque el usuario
  no mencione la palabra "rol" explícitamente. Requiere haber leído
  primero `image-review-domain` (el vocabulario de comprobantes/totales
  que aquí se da por entendido).
---

# Roles y permisos: Revisor y Sumador

Esta skill cubre **quién puede hacer qué y desde dónde**, no el modelo
de negocio de comprobantes/totales (eso vive en `image-review-domain`,
léela primero) ni la persistencia/offline (`image-review-offline-sync`).

## Sistema de roles existente (no reinventar)

El repo ya tiene un patrón completo en `lib/features/admin/` y
`lib/features/auth/` — **reusarlo, no crear uno paralelo**:

- Roles hoy: `admin` y `superAdmin`, como **custom claims booleanos de
  Firebase Auth** (nunca campos editables desde el cliente — ver
  `PROJECT_DOCUMENTATION.md`, sección Convenciones).
- Se leen en `mapToDomain` (`idTokenResult.claims`) y quedan expuestos
  como `AuthenticatedUser.isAdmin` / `.isSuperAdmin`.
- Se asignan desde `AdminPage` → botón "Hacer admin/Quitar admin" →
  Cloud Function `setUserRole`. Ese botón **solo es visible para quien
  ya es `superAdmin`**, y **nunca aplica sobre otro `superAdmin`**: la
  función también lo impone en el servidor (verifica que quien llama sea
  superAdmin y rechaza con `permission-denied` si el usuario objetivo ya
  es superAdmin), porque ocultar el botón no protege una llamada directa.
- `setUserRole` **lee los claims actuales del objetivo, los fusiona
  cambiando solo `admin` y los escribe** (`setCustomUserClaims` reemplaza
  el objeto completo). La versión original escribía solo `{ admin }` y
  borraba cualquier otro claim (bug corregido).
- Las mutaciones de `AdminNotifier` **no son todas optimistas ni se
  deshacen igual**: `toggleUserStatus` actualiza el estado local antes y,
  si falla, **revierte en local**; `setUserRole`, `updateUserGroups` y
  `deleteUser` actualizan antes y, si falla, **recargan la lista del
  servidor** (`loadUsers`); `createUser` solo agrega el usuario tras el
  éxito y `updatePassword` no toca la lista. Toda actualización optimista
  debe usar `AppUser.copyWith`: reconstruir el usuario a mano perdía
  `isAdmin`/`isSuperAdmin` (bug corregido) y dejaba ver "Hacer admin" en
  la tarjeta de un superAdmin.

## Reglas nuevas para Revisor y Sumador

1. **`revisor` y `sumador` son mutuamente excluyentes entre sí** (nunca
   ambos activos en el mismo usuario): esto es una regla de negocio
   antifraude, no un detalle técnico — si la misma persona pudiera ser
   Revisor y Sumador de una misma imagen, la doble verificación
   (`image-review-domain`, regla 2) pierde sentido. **Comportamiento
   confirmado**: al activar uno de los dos, el otro se **desactiva
   automáticamente** (no se bloquea el switch pidiendo que primero
   desactiven el contrario a mano — el propio superAdmin activa uno y
   el sistema apaga el otro solo). **Sí siguen siendo independientes de
   `admin`/`superAdmin`**: un usuario puede ser `admin` + `revisor`, o
   `superAdmin` + `sumador`, etc. — la exclusión es únicamente entre
   `revisor` y `sumador` entre sí.
2. **Activación exclusiva desde `AdminPage`, exclusiva del superAdmin —
   ✅ HECHA (sin desplegar todavía)**: en `_UserCard`, el punto de
   entrada del rol ("Rol de revisión" + el texto de estado) solo es
   visible si `AuthenticatedUser.isSuperAdmin == true` para quien está
   mirando el panel. Un `admin` normal (no super) no lo ve. **Dos puntos
   de entrada separados** (no un solo diálogo combinado, a diferencia
   del extinto `ReviewAssignmentDialog`): el rol en sí desde `_UserCard`
   (`ReviewRoleDialog`), y los horarios (grupo+jornada) por grupo desde
   `AssignGroupsDialog` ("Horarios") — ver el detalle completo en
   "Asignación de grupo + jornada" más abajo, que es la fuente de verdad
   de la forma final.
3. **Nunca se activan desde el cliente sin pasar por Cloud Function**:
   se necesita una Cloud Function nueva (o extender `setUserRole` para
   aceptar el nombre del rol como parámetro) — seguir el patrón
   **corregido** de `setUserRole` (**leer** los claims actuales con
   `getUser`, **fusionar** cambiando solo el claim propio, **escribir**;
   nunca `setCustomUserClaims` con un objeto parcial: el patrón original
   tenía ese bug de merge y borraba los demás claims), con la
   verificación server-side de quien llama y, en `AdminNotifier`, la
   actualización optimista con `AppUser.copyWith` (y recargar del
   servidor si falla, como `setUserRole`). La Cloud Function es también
   el lugar correcto para aplicar la exclusión mutua (regla 1): al
   setear `revisor=true` debe apagar `sumador` (y viceversa) de forma
   atómica en el mismo custom claim, no confiar solo en que el cliente
   mande el estado correcto.
4. **`AuthenticatedUser` gana dos campos nuevos**: `isRevisor` /
   `isSumador`, leídos del mismo `idTokenResult.claims` que hoy da
   `isAdmin`/`isSuperAdmin`. **Ver también la sección "Asignación de
   grupo + jornada" más abajo** — estos dos booleanos no bastan solos,
   cada rol activo viene acompañado de un grupo y una jornada
   asignados.

## Alcance de dispositivo: solo tablet/PC

- El **formulario de captura** en `image_detail_page` (números,
  totales, anotaciones — ver `image-review-domain`) es funcionalidad
  **exclusiva de pantallas tablet/PC. Nunca aparece en mobile/celular**,
  aunque el proyecto tenga implementaciones mobile y web del visor.
- Esto es una restricción **de este formulario específico**, no de todo
  `ImageDetailPage` — el visor de imágenes en sí (zoom, navegación,
  gestos) sigue funcionando igual en mobile; simplemente ese dispositivo
  nunca muestra el panel de captura de Revisor/Sumador.
- Implementación: el umbral `mobile = 600` no alcanza para distinguir
  "mobile real" de "tablet", así que se agregó
  **`AppBreakpoints.reviewForm = 840`** (clase de ventana "expanded" de
  Material 3; entre 600 y 840 hay tablets verticales y celulares
  horizontales). **Adoptado, pendiente de validar en dispositivos
  reales** (tablet vertical/horizontal, laptop).
  - Con ancho < 840 el visor es exactamente el de siempre: sin panel,
    sin bloqueo de avance y sin cambios de atajos.
  - Con ancho ≥ 840 el panel va a la derecha de la imagen, con ancho
    `AppSizes.reviewPanelWidth(screenWidth)` (34 %, entre 360 y 440).
- Un usuario con rol Revisor o Sumador que entra desde un celular debe
  poder seguir viendo las imágenes normalmente; solo no ve el
  formulario de captura ahí.

## Validación: no se puede cambiar de imagen sin completar el formulario

- Si el usuario activo tiene rol Revisor o Sumador **y** está en una
  pantalla donde el formulario aplica (tablet/PC), **no puede cambiar de
  imagen en el visor mientras la imagen actual no tenga un registro
  guardado**. El bloqueo es **en AMBAS direcciones** (las dos flechas
  del teclado, los dos chevrons y el swipe hacia ambos lados), porque el
  Revisor puede empezar desde cualquier imagen (muy probablemente la
  última que ve) y por eso **no hay una dirección de avance confiable**.
  Feedback: SnackBar "Guarda el formulario para continuar" (y tooltip en
  los chevrons deshabilitados).
- Con la imagen actual **ya registrada** la navegación es libre en ambos
  sentidos, también en modo "Editar" con cambios sin guardar (el
  borrador se conserva al volver). **Cerrar el visor siempre está
  permitido** (Esc sin campo enfocado o el botón de cerrar).
- "Completar" = **guardar** (botón "Guardar" explícito): llenar los
  campos no basta, se navega solo cuando existe un registro guardado.
  Los campos obligatorios son los definidos en `image-review-domain`.
  Para los dos roles: el **código de la imagen** (uno por foto, un solo
  campo arriba de las tarjetas) y al menos un comprobante. Para el
  **Revisor**, cada comprobante con al menos un número y total > 0. Para
  el **Sumador**, cada comprobante con total > 0, sin números. Ambas
  reglas están implementadas en `validateImageReviewForm(form, rol)`. Las
  anotaciones y la lotería de cada comprobante ("Lotería (opcional)")
  nunca son obligatorias.
- Esta validación es **de navegación dentro del visor**, no de guardado:
  no impide cerrar la app o salir de `image_detail_page` por completo,
  solo bloquea el gesto/flecha/botón de cambio de imagen mientras falte
  el registro de la imagen actual.
- **Es una guía de flujo, no un candado**: quien puede saltarse una
  imagen (cerrando el visor y abriendo otra) no queda registrado como
  error. Lo que detecta los faltantes es la **reconciliación agregada del
  resumen** (`image-review-domain`, regla 3), no este bloqueo.
- El bloqueo de un swipe se decide con la imagen sobre la que **empezó**
  el gesto, no con la de destino: un arrastre que empieza en una imagen
  registrada nunca se congela a mitad de camino.
- Un usuario que **no** tiene rol Revisor ni Sumador (ej. un usuario
  normal, o un `admin`/`superAdmin` sin esos roles activados) navega el
  visor exactamente igual que hoy, **sin ningún formulario, ni siquiera
  en modo lectura** — simplemente ve la imagen. El formulario de captura
  solo existe para quien tiene activa la cualidad Revisor o Sumador.
- **Edición de un registro ya diligenciado**: si Revisor/Sumador
  navega (buscando manualmente, sin atajo — ver `image-review-offline-sync`)
  hasta una imagen que **ya tiene un registro guardado** (local o ya
  subido), `image_detail_page` debe mostrar un **botón "Editar"** en
  vez de un formulario vacío. El bloqueo de navegación (arriba) no
  aplica sobre una imagen que ya tiene registro — esa restricción es
  solo para imágenes sin diligenciar todavía.

## Identificación del autor del registro

- Cada usuario ya tiene su propio correo (`AuthenticatedUser`/`users`).
  Cuando se guarda un registro (local u online, ver
  `image-review-offline-sync`), debe llevar el **correo del usuario que
  lo diligenció** (Revisor o Sumador) como dato de auditoría — así se
  puede rastrear quién anotó qué sin necesitar una entidad nueva de
  "autor". Este campo se agrega a la estructura de "Registro de imagen"
  de `image-review-domain`.
- Qué pasa operativamente si a alguien le quitan el rol mientras tiene
  registros sin subir en local **no está resuelto por la app** — queda
  como una decisión operativa de quien administra (el superAdmin), no
  como una regla que el código deba imponer automáticamente por ahora.

## Asignación de grupo + jornada — CONFIRMADA (modelo de LISTA)

El usuario confirmó explícitamente esto: **cada Revisor y cada Sumador
tiene asignados uno o más grupos, cada uno con su propia jornada** a
revisar — el rol no aplica de forma genérica a todos los
grupos/jornadas. **Este modelo reemplaza uno anterior** que asumía una
sola asignación (grupo + jornada) por persona; se descartó por datos
reales: las cuentas de Revisor/Sumador en producción cubren VARIOS
grupos cada una (ejemplo real: 8 grupos en una sola cuenta), algunos
grupos se repiten entre distintas personas del mismo rol (cada una
cubriendo jornadas distintas de ese grupo), y Revisor/Sumador de un
mismo grupo **no** necesitan cubrir las mismas jornadas entre sí. Nada
de la versión anterior llegó a desplegarse, así que el reemplazo es
limpio (sin migración de datos).

- **Unicidad**: dos personas con el mismo rol (dos Revisores, o dos
  Sumadores) **nunca pueden cubrir el mismo grupo y la misma jornada a
  la vez**. Un Revisor y un Sumador **sí** pueden (de hecho, deben)
  compartir grupo+jornada — son ellos dos quienes se verifican
  mutuamente sobre esa misma combinación. La unicidad es por la
  **tupla** `(rol, chatJid, shift)`, evaluada contra las entradas de
  TODAS las personas de ese rol, no por persona.
- **Modelo, en dos partes** (ya no un solo claim combinado):
  - El **rol** (`revisor` | `sumador` | ausente) es un **custom claim
    simple**, `reviewRole` — un string, no un objeto: al mover
    grupo+jornada a Firestore (ver abajo), lo único que le queda al
    claim es "esta cuenta es Revisor/Sumador/ninguno", que ya es un
    valor único por cuenta (la exclusión mutua Revisor/Sumador de la
    regla 1 sigue siendo inherente: solo puede haber un valor).
  - La **lista de (grupo, jornada)** que esa cuenta cubre bajo su rol
    vive en **Firestore**, `users/{uid}.reviewShifts: [{chatJid,
    shift}]` — NO en el claim: un array de varias tuplas por persona
    (hasta ~8 grupos reales, con margen) arriesgaba acercarse al
    límite de 1000 bytes de los custom claims si se hubiera quedado ahí.
    `shift` es el **nombre del valor de `enum Shift`** en Dart
    (`morning`, `afternoon1`, `afternoon2`, `night1`, `night2`,
    `holiday`), no la etiqueta en español; `outOfShift` NO es
    asignable. La lista de jornadas asignables está espejada a mano en
    `ASSIGNABLE_SHIFTS` (`functions/index.js`) y debe mantenerse
    sincronizada con `lib/core/time/shifts.dart`. Con la tabla única
    (paso 7, pieza e) el cliente ya no ofrece `night2`, pero
    `ASSIGNABLE_SHIFTS` todavía la acepta (PENDIENTE retirarla).
    Ojo: los registros de `image_review` guardan `shift` como la
    **etiqueta** (`shiftNames`, las actuales; los registros viejos pueden
    traer una de `legacyShiftNames`), así que al comparar una asignación
    con un registro/mensaje habrá que traducir enum ↔ etiqueta
    (`shiftFromLabel` reconoce las dos).
- **Cloud Functions — backend ✅ HECHO y probado, sin desplegar
  todavía** (reemplazan a la extinta `setReviewAssignment`, que
  guardaba un solo `{role, chatJid, shift}` combinado):
  - **`setReviewRole(uid, role)`** — `role: 'revisor' | 'sumador' |
    null`. Solo superAdmin. Mismo patrón que `setUserRole` (leer con
    `getUser`, fusionar cambiando solo `reviewRole`, escribir; conserva
    `admin`/`superAdmin`/lo demás). A diferencia de `setUserRole`, SIN
    guarda contra un objetivo superAdmin: un superAdmin SÍ puede tener
    rol de revisión (intencional, con test, igual que antes). `null`
    desactiva — se BORRA la clave `reviewRole` de los claims en vez de
    escribir `null` (una sola representación de "sin rol", ni un byte
    del límite de 1000). **Si el rol cambia de verdad** (no una
    reasignación del mismo valor), limpia `reviewShifts` a `[]` en
    Firestore en la misma llamada: las jornadas que cubría bajo el rol
    anterior no tienen sentido bajo el nuevo. Riesgo aceptado y ya
    conocido en el proyecto: esta limpieza no es atómica con la
    escritura del claim (Auth y Firestore son sistemas separados), no
    se resuelve con infraestructura nueva.
  - **`updateReviewShifts(uid, shifts)`** — `shifts: [{chatJid,
    shift}]`, sin `role` por entrada (se deriva del `reviewRole` actual
    del uid objetivo, leído de Auth). Solo superAdmin. Rechaza con
    `failed-precondition` si el objetivo no tiene `reviewRole` asignado
    (sin rol no hay bajo qué unicidad evaluar). Valida cada entrada:
    `chatJid` existe en `group_stats` (consulta por el CAMPO `chatJid`,
    como el resto del proyecto, una por entrada) y `shift` está en
    `ASSIGNABLE_SHIFTS`. **Reemplaza la lista completa** en
    `users/{uid}.reviewShifts` (patrón de `updateUserGroups`: reemplazo
    total, no merge parcial — una entrada vieja que no viene en el
    payload nuevo desaparece). Si hay conflicto de unicidad, **rechaza
    toda la operación** (todo-o-nada) y el error (`already-exists`)
    trae en `details.conflicts` **todas** las tuplas en conflicto, no
    solo la primera, para que el cliente las marque de una vez sin
    reintentos en serie.
    - **Algoritmo de unicidad** (evita una segunda pasada completa de
      `listUsers` o escanear toda la colección `users`): 1) un solo
      `auth().listUsers(1000)` trae los claims de todos, incluido
      `reviewRole` (gratis); 2) se filtra a los uids con `reviewRole`
      (típicamente un subconjunto chico), excluyendo el propio uid; 3)
      un solo `firestore.getAll(...)` en lotes de 30 sobre ESOS uids
      trae sus `reviewShifts` (mismo patrón de lotes que ya usa
      `listUsers`); 4) se arma el set de tuplas ocupadas `(rol del
      otro, chatJid, shift)` y se compara contra el payload. Límites
      aceptados (igual que el resto del archivo): hereda el tope de
      1000 usuarios de `listUsers` (sin paginar) y no hay transacción
      entre el chequeo y la escritura.
- **`listUsers`** devuelve `reviewRole` (`'revisor' | 'sumador' |
  null`) y `reviewShifts` (`[]` si no hay datos) en la misma respuesta
  de cada usuario — mismo lote de `getAll` que ya usaba para
  `allowedGroups`, sin pasada extra.
- Los custom claims completos comparten 1000 bytes (`admin`,
  `superAdmin`, `reviewRole`); con `reviewRole` como string simple
  sobra de lejos.
- **UI en `AdminPage` — ✅ HECHA (sin desplegar todavía), dos puntos de
  entrada separados**:
  - **Rol**: en `_UserCard`, un botón "Rol de revisión" (visible SOLO
    para un superAdmin, SIN condición sobre el rol del objetivo — igual
    que antes) abre `ReviewRoleDialog`: radios Ninguno/Revisor/Sumador
    (extraídos en `ReviewRoleRadioGroup`, reutilizable). Si el usuario
    ya tiene `reviewShifts` no vacío y el valor elegido es distinto del
    actual, advierte "Esto borrará los N horarios ya asignados a esta
    persona." antes de confirmar (el servidor los limpia de verdad, ver
    arriba). Al confirmar, llama `AdminNotifier.setReviewRole` y cierra
    de inmediato (fire-and-forget, como "Hacer admin/Quitar admin": no
    espera la respuesta, confía en que es optimista y siempre recarga).
    El texto de estado junto al botón muestra solo "Revisor"/"Sumador"/
    "Sin asignar revisión" — sin listar horarios ahí.
  - **Horarios**: en `AssignGroupsDialog`, cada fila de grupo (ya no
    `CheckboxListTile`, sino `Checkbox` + texto + botón, para poder
    agregar un segundo control) tiene un botón "Horarios" que aparece
    SOLO si el checkbox de ese grupo está marcado Y el usuario tiene
    `reviewRole` activo. Abre `GroupShiftsDialog` (diálogo anidado,
    `showDialog` sobre `showDialog`) con las 5 jornadas asignables
    (`assignableShifts`: sin `night2` ni `outOfShift`) como checkboxes
    (`shortShiftName(shiftNames[shift]!)`). Las jornadas ya
    cubiertas por OTRA persona del MISMO rol llegan deshabilitadas, con
    su email como subtítulo — calculado del lado del cliente con
    `AdminState.users` (ya trae `reviewRole`+`reviewShifts` de todos,
    sin llamada extra), para coordinar entre superAdmins antes de que el
    servidor rechace por conflicto. La selección por grupo vive en
    memoria en el diálogo padre, indexada por `chatJid` e independiente
    de si el checkbox de ese grupo está marcado en ese instante: si se
    desmarca y se vuelve a marcar antes de Guardar, sus horarios
    reaparecen tal cual. Al Guardar el diálogo padre, llama
    `updateUserGroups` y, si hay `reviewRole`, también
    `updateReviewShifts` con las entradas de los grupos que siguen
    marcados. Si el servidor igual rechaza por conflicto (carrera entre
    dos superAdmins), el diálogo NO se cierra, muestra el mensaje de
    `AdminFailure.reviewShiftConflict` y recarga (`loadUsers()`, ya lo
    hace `AdminNotifier.updateReviewShifts` en cualquier desenlace) para
    que el resaltado quede al día en el siguiente intento.
- **Hecho**: `AuthenticatedUser` lee `reviewRole` del claim
  (`mapToDomain`, con el mismo parseo defensivo por valor inesperado
  que ya existía del lado de admin) y `currentReviewRoleProvider` lo usa
  como fuente real — ver "Rol activo" más abajo, ya no es temporal.
  `reviewShifts` se lee aparte (no es parte de `AuthenticatedUser`), en
  `reviewShiftsProvider`, con el mismo patrón de lectura única que
  `fetchAllowedGroups` (sin `.snapshots()`). No hay, y nunca hubo,
  ningún filtrado de `ChatList` involucrado en esto — ver el punto
  siguiente.
- Deploy: **ya desplegado a producción** (`setReviewRole` y
  `updateReviewShifts` confirmadas vivas vía `firebase functions:list`).
- **No es un filtrado de qué chats se ven**: `allowedGroups` sigue
  intacto, sin ningún cambio — un Revisor/Sumador sigue viendo la
  misma lista de chats que vería igual sin rol. Lo que `reviewShifts`
  condiciona es otra cosa: si se muestra el **formulario de captura**
  dentro de una imagen puntual. Existe una TERCERA condición, además
  de `ancho >= AppBreakpoints.reviewForm && rol != null` (ver "Rol
  activo" más abajo): que esa imagen puntual pertenezca a un
  `(chatJid, shift)` presente en el `reviewShifts` ACTUAL de esa
  persona para su rol (`reviewShiftsProvider`). Sin esa tercera
  condición, la persona ve la imagen exactamente igual que un usuario
  sin rol — navega libre, sin bloqueo de navegación, sin formulario.
  - **Regla nueva, explícita y confirmada**: si a alguien le quitan una
    jornada de su `reviewShifts`, pierde el derecho al formulario ahí
    **aunque ya tuviera un registro guardado** — el botón "Editar"
    tampoco debe aparecer para esa imagen. Es una regla de código, no
    una decisión operativa: distinta (y más estricta) que el punto
    pendiente ya existente sobre "qué pasa si le quitan el ROL
    COMPLETO con registros locales sin subir" (sección "Identificación
    del autor del registro", arriba — esa sigue sin resolver, a
    criterio del superAdmin). Acá, con el rol todavía activo pero esa
    jornada puntual removida, el acceso se pierde igual, sin
    excepción para lo ya guardado.
  - **Implementado** en `image_detail_page.dart`: la jornada de la
    imagen es una etiqueta en español (`ImageViewItem.shift`,
    p. ej. "Jornada Mañana (05:30 – 10:51)"), traducida al enum con
    `shiftFromLabel` (`core/time/shifts.dart`, inverso de `shiftNames` y
    de `legacyShiftNames`)
    antes de comparar contra `reviewShifts`. Existen dos copias de la
    condición completa (ancho + rol + asignación), como ya pasaba antes
    con ancho + rol: `_showReviewPanelFor(item)` (usa `ref.read`, para
    `_isNavigationBlocked` y para pedir foco tras cambiar de página) y
    el cálculo inline de `showPanel` en `build()` (usa `ref.watch`) —
    ambas comparten la lógica de match vía la función de nivel superior
    `_matchesAssignment`. Mientras `reviewShiftsProvider` está
    `AsyncLoading` o en error se trata igual que "sin asignación" (sin
    panel), para no mostrarlo de forma transitoria y ocultarlo después
    al resolver.
- **Por qué esto refuerza el diseño de cierre de jornada**
  (`image-review-domain`, sección "Cierre de jornada"): como cada
  jornada+grupo tiene un único responsable por rol, no hay ambigüedad
  sobre quién decide "ya terminé de registrar" — es literalmente la
  única persona con esa asignación.
- **Rol activo (`currentReviewRoleProvider`)**: la fuente real es el
  claim `reviewRole` de `AuthenticatedUser` (sesión autenticada) —
  puede ser `null` (sin rol), y esa YA es la respuesta final, no hay
  fallback en ese caso. Sin sesión autenticada real
  (`loading`/`unauthenticated`: desarrollo local antes de conectar
  login, o tests que no simulan sesión) cae a
  `--dart-define=REVIEW_ROLE=revisor|sumador` como fallback de
  desarrollo, para no romper ese flujo de prueba ya existente; sin el
  parámetro, o con un valor inválido, el fallback también da `null`
  (se avisa con `debugPrint`). Para probar el feature en local sin
  sesión hay que pasar el flag a mano (`flutter run
  --dart-define=REVIEW_ROLE=revisor`). Es el ÚNICO punto que decide el
  rol activo. Borrador, registro guardado y bloqueo de navegación se
  indexan por (`messageId`, rol) (`ReviewKey`), así que cada rol ve
  solo lo suyo de la imagen actual.
- **Conducta con rol == null** (todo lector del provider tiene su rama
  explícita): el visor no muestra el panel (`showPanel` = ancho >=
  `AppBreakpoints.reviewForm` **y** rol != null **y** hay asignación
  para esa imagen en `reviewShifts`, ver el punto de arriba) ni
  construye `ReviewKey`, y la navegación es libre; `ImageReviewPanel`
  retorna `SizedBox.shrink()` si aun así se construye;
  `pendingUploadsProvider` da lista vacía sin consultar el repositorio;
  `PendingUploadIndicators` no muestra nada; `ReviewUploadNotifier.upload()`
  no hace nada (retorna null). En los tests se fuerza con
  `currentReviewRoleProvider.overrideWithValue(null)`; los tests que
  necesitan el panel deben fijar el rol Y una asignación que matchee
  explícitamente (ya no hay default Revisor, ni asignación por
  defecto).

## Acceso a Resumen y Coincidencias — DECIDIDO: solo admin y superAdmin

- `/summary` (Resumen) y `/matches` (Coincidencias) solo se abren con claim
  `admin` o `superAdmin`, y solo esas cuentas ven sus entradas en el menú
  de `ChatList`. **Revisor y Sumador no ven el Resumen** (ni ningún dato de
  `image_reviews`): su rol solo gobierna el formulario de captura.
- Helpers separados con la misma regla hoy (`isAdmin || isSuperAdmin`), para
  poder divergir: `canViewSummary` (`features/summary/domain/helpers/`) y
  `canViewMatches` (`features/matches/domain/helpers/`). Cada uno lo usan el
  guard (`computeAuthRedirect`, `lib/app/auth_redirect.dart`: sin permiso →
  `/home`; sin sesión → `/login`, como siempre) y el menú, para que nunca
  diverjan entre sí. `reviewRole` no suma ni resta.
- **PENDIENTE (no decidido)**: si algún día Revisor o Sumador deben ver
  sus propias sumas, haría falta una Cloud Function que se las entregue
  (toca `functions/`), porque no leen `image_reviews`. **Desfase de
  claims**: el cliente lee los claims solo al iniciar sesión
  (`getIdTokenResult(true)` en `mapToDomain`), así que a un admin al que le
  quiten el rol puede seguir viendo el Resumen y Coincidencias hasta que se
  renueve el token (nuevo login o recarga de sesión).

## Zona gris / a confirmar antes de implementar

- **Validar `reviewForm = 840` en dispositivos reales** (tablet
  vertical/horizontal, laptop): el valor está adoptado y funcionando,
  pero no es una decisión cerrada (ver sección de dispositivo arriba).
