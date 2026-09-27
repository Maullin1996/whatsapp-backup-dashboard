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
   backend ✅ HECHO, UI ⚠️ PENDIENTE de reescribir**: en `_UserCard`, el
   punto de entrada (rol + horarios) solo debe ser visible si
   `AuthenticatedUser.isSuperAdmin == true` para quien está mirando el
   panel. Un `admin` normal (no super) no debe verlo. La UI actual en el
   repo (`ReviewAssignmentDialog`, un solo diálogo con rol+grupo+jornada
   combinados) quedó **obsoleta**: el modelo real es un claim de rol
   simple más una **lista** de (grupo, jornada) por cuenta, no una tupla
   única — ver "Asignación de grupo + jornada" más abajo, que es la
   fuente de verdad de la forma final. La UI para este modelo nuevo es
   la próxima tarea.
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
  Para el **Revisor**: al menos un
  comprobante, y cada comprobante con código, al menos un número y
  total > 0. Para el **Sumador**: al menos un comprobante, y cada
  comprobante con código y total > 0, sin números. Ambas reglas están
  implementadas en `validateImageReviewForm(form, rol)`. Las
  anotaciones nunca son obligatorias, son siempre opcionales.
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
    sincronizada con `lib/core/time/shifts.dart` hasta que las jornadas
    vengan del Firebase externo (`image-review-firebase-integration`).
    Ojo: los registros de `image_review` guardan `shift` como la
    **etiqueta** (`shiftNames`), así que al comparar una asignación con
    un registro/mensaje habrá que traducir enum ↔ etiqueta.
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
- **UI en `AdminPage` — ⚠️ PENDIENTE de reescribir (próxima tarea, en
  un prompt aparte)**: el código actual en el repo
  (`ReviewAssignmentDialog`, `AdminNotifier`/`AdminRepository/
  AdminDatasourceImpl.setReviewAssignment`, `AdminFailure.reviewAssignmentConflict()`,
  la entidad `ReviewAssignment`, el campo `AppUser.reviewAssignment`)
  sigue apuntando al modelo viejo de una sola asignación y llama a una
  Cloud Function que **ya no existe** — es código muerto hasta que se
  rediseñe para el modelo de lista (rol simple + un mecanismo de
  "horarios" por grupo, forma exacta todavía sin definir).
- Pendiente (siguiente capa, después de la UI): `AuthenticatedUser`
  leyendo `reviewRole`/`reviewShifts` y conectar
  `currentReviewRoleProvider` (y el filtrado de `ChatList`) a los
  claims/datos reales.
- Deploy: NO desplegado (requiere autorización explícita aparte).
- **Filtrado de qué ve cada uno**: un Revisor/Sumador probablemente solo
  debería ver/trabajar en los grupos y jornadas que tiene asignados —
  parecido al filtrado por `allowedGroups` que ya existe para usuarios
  normales (`ChatsFirestoreDatasource`), pero acotado además por
  jornada dentro de cada chat, y ahora sobre una lista en vez de una
  sola combinación. El detalle exacto de cómo se refleja esto en
  `HomePage`/`ChatList`/`image_detail_page` queda para cuando se
  implemente esta pieza (ver `image-review-workflow`).
- **Por qué esto refuerza el diseño de cierre de jornada**
  (`image-review-domain`, sección "Cierre de jornada"): como cada
  jornada+grupo tiene un único responsable por rol, no hay ambigüedad
  sobre quién decide "ya terminé de registrar" — es literalmente la
  única persona con esa asignación.

## Zona gris / a confirmar antes de implementar

- **Validar `reviewForm = 840` en dispositivos reales** (tablet
  vertical/horizontal, laptop): el valor está adoptado y funcionando,
  pero no es una decisión cerrada (ver sección de dispositivo arriba).- **Rol activo TEMPORAL (`currentReviewRoleProvider`)**: mientras no
  existan los roles reales (custom claims `revisor`/`sumador`), el rol con
  el que se abre el formulario sale de
  `--dart-define=REVIEW_ROLE=revisor|sumador`. Sin el parámetro, o con un
  valor inválido, el default es **sin rol** (`ReviewRole?` = null; se avisa
  con `debugPrint`): refleja el caso más común en producción (nadie
  asignado), no el de desarrollo. Para probar el feature en local hay que
  pasar el flag a mano (`flutter run --dart-define=REVIEW_ROLE=revisor`).
  Es el ÚNICO punto que decide el rol activo: al conectar los claims solo
  cambia ese provider. Borrador, registro guardado y bloqueo de navegación
  se indexan por (`messageId`, rol) (`ReviewKey`), así que cada rol ve solo
  lo suyo de la imagen actual.
- **Conducta con rol == null** (todo lector del provider tiene su rama
  explícita): el visor no muestra el panel (`showPanel` = ancho >=
  `AppBreakpoints.reviewForm` **y** rol != null; antes dependía solo del
  ancho) ni construye `ReviewKey`, y la navegación es libre;
  `ImageReviewPanel` retorna `SizedBox.shrink()` si aun así se construye;
  `pendingUploadsProvider` da lista vacía sin consultar el repositorio;
  `PendingUploadIndicators` no muestra nada; `ReviewUploadNotifier.upload()`
  no hace nada (retorna null). En los tests se fuerza con
  `currentReviewRoleProvider.overrideWithValue(null)`; los tests que
  necesitan el panel deben fijar el rol explícitamente (ya no hay default
  Revisor).
