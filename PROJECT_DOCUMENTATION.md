# WhatsApp Monitor Viewer — Documentación del proyecto

> Este documento resume qué es la app, cómo está construida y qué hace cada pantalla/feature.
> Pensado como contexto para arrancar nuevas features (por ejemplo, subido a un Proyecto de Claude).

---

## 1. Qué es la app

Plataforma de monitoreo de grupos de WhatsApp en tiempo real. Un bot de WhatsApp (externo, no vive en este repo) empuja mensajes e imágenes a Firebase (Firestore + Storage), y esta app Flutter los muestra en un visor estructurado con control de acceso por roles: cada usuario solo ve los grupos de WhatsApp que un admin le asignó.

Se usa principalmente como **PWA web** (desplegada en Firebase Hosting), aunque el proyecto Flutter también trae scaffolding para Android/iOS/Windows/macOS/Linux (no es el foco actual de desarrollo/pruebas).

**Project ID de Firebase:** `whatsapp-pro-3d483`.

---

## 2. Stack técnico

- **Flutter** (Dart), Material 3, `MaterialApp.router`.
- **Riverpod** (`flutter_riverpod` v3) para todo el manejo de estado.
- **go_router** para navegación declarativa con guards de auth/rol.
- **Firebase**: Auth (email/password + custom claims), Cloud Firestore, Cloud Storage, Cloud Functions (Node.js).
- **Freezed** para entidades/estados inmutables y errores tipados.
- **dartz** (`Either<Failure, T>`) para manejo de errores sin excepciones en la capa de datos/dominio.
- **extended_image** para carga/caché de imágenes de red y el visor con zoom/gestos.
- **shimmer** para los skeletons de carga.
- **hive_ce** / **hive_ce_flutter** — persistencia local del feature de revisión de imágenes (formularios y registros de Revisor/Sumador pendientes de subir, por jornada). Ver `.claude/skills/image-review-offline-sync.md`.
- Locale único: **español** (`es`), hardcodeado en `app.dart`.

---

## 3. Arquitectura

Clean Architecture estricta, separada por feature. Cada feature en `lib/features/<nombre>/` tiene tres capas:

```
presentation/   → Páginas, Widgets, Riverpod Providers, Notifiers (AsyncNotifier/Notifier)
domain/         → Entidades (Freezed o clases planas), interfaces de Repository, helpers de mapeo
data/           → Implementaciones de Repository, DataSources (Firestore/Storage/Functions), Models "raw"
```

Flujo de dependencias: `app/providers.dart` → datasources → implementaciones de repository → repositorios de dominio → notifiers/providers → UI.

Código compartido:
- `lib/core/` — `errors/` (Failures tipados), `responsive/` (breakpoints y layout), `theme/` (design system, ver abajo), `time/` (jornadas/turnos), `loading/` (shimmer), `shared/widget/` (inputs reutilizables).
- `lib/helpers/` — `format_time.dart`, `map_failure_to_message.dart` (traduce cualquier `Failure` a un mensaje en español para mostrar en UI).
- `lib/app/` — `router.dart` (rutas + guards), `providers.dart` (inyecta `FirebaseAuth`/`FirebaseFirestore`/`FirebaseStorage` a los datasources), `app.dart` (`MaterialApp.router`, tema global, locale).

### Manejo de errores

Todas las capas de datos devuelven `Either<Failure, T>` (nunca lanzan excepciones hacia arriba). Los `Failure` son uniones selladas con Freezed en `lib/core/errors/` (`AuthFailure`, `AdminFailure`, `FirestoreFailure`, `Failure` genérico). `mapFailureToMessage` los convierte a texto en español para SnackBars/mensajes de error en pantalla.

### Manejo de estado (Riverpod)

- `AsyncNotifierProvider` — datos async con loading/error (lista de chats, mensajes).
- `NotifierProvider` — estado síncrono de UI (formulario de login, estado del panel de admin).
- `StreamProvider` / streams internos — listeners de Firestore en tiempo real.
- `Provider.family` — providers parametrizados (p. ej. `imageUrlProvider(storagePath)`).
- `ref.listen` en `build()` de un `ConsumerWidget` — efectos secundarios (navegación post-login, SnackBars de éxito/error).

---

## 4. Sistema de diseño (`lib/core/theme/`)

Todo el look & feel vive en tokens reutilizables, más un `ThemeData` global. Importa todo con:
`import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';`

| Archivo | Contenido |
|---|---|
| `app_theme.dart` (`AppTheme.light`) | `ThemeData` global (usado en `MaterialApp.router(theme: AppTheme.light)`). Fija defaults de `AppBar`, botones, `Card`, `Dialog`, `BottomSheet`, `PopupMenu`, inputs, `Switch`/`Checkbox`/`Radio`, `Divider`, `Chip`, `SnackBar`, `Tooltip`. |
| `app_colors.dart` (`AppColors`) | Paleta: `primaryGreen`, `loadingColor`, `errorMessage`, `upLoginBackground`/`downLoginBackground`, `inputBackground`/`inputBorder`, `screenBackground`, `accentTeal`, `roleAdmin`/`roleSuperAdmin`, `success`, `divider`, `activeTile`. |
| `app_spacing.dart` (`AppSpacing`) | Escala `xs=4, sm=8, md=12, lg=16, xl=24`. |
| `app_radius.dart` (`AppRadius`) | Radios con nombre (`thumbnail=6, button=8, tile=10, card=12, skeletonCard=14, dialog=16, search=18, pill=20`) + versiones ya resueltas como `BorderRadius` (`AppRadius.buttonAll`, etc.). |
| `app_shadows.dart` (`AppShadows`) | `bubble` (sutil) y `loginCard` (la única sombra fuerte de la app). |
| `app_sizes.dart` (`AppSizes`) | Anchos máx. de contenido en desktop (`loginFormMaxWidth`, `adminPanelMaxWidth`, `messageBubbleMaxWidth`, `emptyStateMaxWidth`), `chatAvatarRadius`, `AppSizes.chatListWidth(screenWidth)`. |
| `app_durations.dart` (`AppDurations`) | Duraciones de animación con nombre (`hover`, `quick`, `pageTransition`, `chatItemAppear`, `messageItemAppear`, `stateSwitch`, `scrollToLatest`, `shimmer`). |
| `app_typography.dart` (`AppTypography`) | Estilos con nombre para patrones repetidos: `senderName(context)`, `timestamp(context)`, `headerTitle(context)`, `adminAppBarTitle`, `badge`, `chatTileTitle`, `avatarInitials`. |

Responsive: un único sistema de breakpoints en `lib/core/responsive/breakpoints.dart` (`AppBreakpoints`):
- `mobile = 600` — breakpoint general (`ResponsiveLayout(mobile:, desktop:)`).
- `homeSplit = 700` — breakpoint específico de `HomePage` para su layout de dos paneles (lista de chats | conversación).

La guía completa de convenciones de UI (patrones de diálogos, estados carga/vacío/error, cuándo usar cada token, etc.) vive en `.claude/skills/ui-design/SKILL.md`.

---

## 5. Firebase

### Firestore — colecciones

| Colección | Campos clave | Uso |
|---|---|---|
| `users` | `uid`, `email`, `allowedGroups[]`, `isAdmin`, `disabled` | Perfil + permisos de cada usuario de la app. `allowedGroups` determina qué chats puede ver. `isAdmin` es un espejo escrito por `setUserRole` (la fuente de verdad son los custom claims). `isSuperAdmin` **NO** se guarda acá — solo existe como custom claim (ver más abajo). |
| `group_stats` | `chatJid`, `groupName`, `lastMessageAt`, `totalImages` | Metadata de cada grupo de WhatsApp monitoreado (una fila por grupo). Fuente de la lista de chats. |
| `whatsapp_messages` | `chatJid`, `senderName`, `messageTimestamp`, `caption`, `hasMedia`, `storagePath`, `isEdited`, `messageDate`, `localTime`, `shiftImageIndex` | Cada mensaje del grupo (texto y/o imagen/video/audio). |
| `edit_attempts` | (por `messageId`) | Auditoría de intentos de edición de un mensaje de WhatsApp; se usa para marcar mensajes como "Editado" en la UI. |
| `image_reviews` **(PROVISIONAL)** | Estructura grupo -> jornada -> registros: `image_reviews/{chatJid}/jornadas/{fechaJornada}_{shiftKey}/registros/{messageId}_{rol}`. Cada registro: `messageId`, `chatJid`, `shift` (etiqueta), `shiftKey` (nombre del enum), `rol`, `storagePath`, `fechaJornada`, `messageTimestamp` (int, ms UTC del mensaje, tal cual), `codigo` (uno por imagen), `comprobantes[]` (cada uno `{numeros, total, loteria}`, `loteria` opcional), `anotaciones`, `registradoEn`, `registradoPor`, `editado` | Registros de Revisor/Sumador del feature de revisión de imágenes. **La subida es real** (`FirestoreReviewUploader`, cableado en `reviewUploaderProvider`) y las reglas de escritura y de lectura de admin **están publicadas desde el 2026-10-01** (copia en `firestore.rules.draft`, ver abajo). La primera escritura real ya se hizo: hay **4 documentos de PRUEBA** que hay que borrar (ver abajo). Nombres definitivos y conectar las lecturas siguen pendientes — ver `.claude/skills/image-review-offline-sync.md` § "Ruta de la subida". |

**Filtrado de chats por permisos**: no es una regla de seguridad automática vía Firestore rules solamente — el datasource (`ChatsFirestoreDatasource`) lee `users/{uid}.allowedGroups` y hace queries `whereIn` sobre `group_stats.chatJid` (en chunks de 30, porque `whereIn` de Firestore tiene ese límite). Si `allowedGroups` está vacío, no se muestra ningún chat.

**Paginación de mensajes**: cursor-based con `startAfterDocument` sobre `whatsapp_messages`, ordenado por `messageTimestamp desc` + `documentId desc` como desempate. Tamaño de página: 50. El filtro de fecha (`DateFilter`) acota el rango con `where messageTimestamp >= from AND < to`.

**Tiempo real**: mientras el filtro de fecha activo incluya "hoy", se abre un listener (`snapshots()`) que escucha solo documentos añadidos con `messageTimestamp` mayor al último conocido, y los mensajes nuevos se agrupan (batching con `Timer` de 200 ms) antes de insertarlos al principio de la lista — evita animar/reordenar en cada mensaje individual si llegan varios juntos.

**Reglas versionadas solo como copia**: no hay `firestore.rules` ni `storage.rules` desplegables en el proyecto. Las reglas de Firestore se publican a mano en la consola y `firestore.rules.draft` es la copia de lo publicado (ver abajo); las de Storage no están en el repo, así que sus permisos no se pueden confirmar desde el código.

**Reglas de Firestore (`firestore.rules.draft`, copia de lo PUBLICADO)**: **publicadas en la consola** (HECHO, verificado por el usuario el 2026-10-01; versión vigente de ese día, 7:37 p.m.). El archivo está en la raíz del repo pero **no se referencia en `firebase.json`** (no hay bloque `firestore`) ni se despliega con la CLI. Se publica a mano pegándolo en la consola de Firebase, lo que reemplaza todo el conjunto de reglas; por eso empieza con una copia exacta de las reglas que ya había en la consola, sin cambios (`whatsapp_messages`, `group_stats`, `edit_attempts`: lectura con sesión, escritura negada; `users/{uid}`: lectura del propio uid, escritura negada). Agrega `create`/`update` de `image_reviews/{chatJid}/jornadas/{jornadaId}/registros/{registroId}` (delete negado): sesión, claim `reviewRole` igual al `rol` del documento, ids coherentes con el payload, `shiftKey` asignable, tipos de las claves y `messageTimestamp`/`chatJid` iguales a los de `whatsapp_messages/{messageId}`. Antes de publicar se probó en parte en la zona de pruebas (claim simulado; detalle en `.claude/skills/image-review-offline-sync.md`). El comentario del encabezado (en el repo y en lo publicado) todavía dice "BORRADOR... no se despliega": está desactualizado y debe corregirse en el repo, para publicarlo cuando cambie otra regla. Cada publicación requiere autorización explícita y comprobar antes que las reglas de la consola no cambiaron.

**Primera escritura real (HECHO, 2026-10-01)**: 4 documentos de **PRUEBA** en la base de producción, en 2 jornadas del 2026-10-01 (`2026-10-01_afternoon2` y `2026-10-01_night1`), con Revisor y Sumador en cada una, escritos con dos cuentas distintas. Confirmado en la consola: la ruta; `codigo` arriba; cada comprobante `{numeros, total, loteria}` (`loteria` null si quedó vacía); el Sumador con `numeros` vacío; `registradoEn` como texto; `total` como int64; `messageTimestamp` como entero; ceros a la izquierda conservados; `fechaJornada` y `shiftKey` coherentes con la hora del mensaje en hora de Colombia. También verificado: el claim `reviewRole` real se evalúa bien para los dos roles y la comparación de `messageTimestamp`/`chatJid` contra `whatsapp_messages` funciona con mensajes reales. **Hay que BORRAR esos 4 documentos desde la consola** antes de desplegar el hosting o de que otra persona use el Resumen: son números de prueba.

**Reglas de lectura de admin (publicadas el 2026-10-01)**: `isAdmin()` (sesión y claim `admin` o `superAdmin` en `true`, leídos con `token.get(..., false)`); `match /{path=**}/registros/{registroId}` con solo lectura para `isAdmin()` (el comodín recursivo es el que exige la consulta de grupo de colecciones del Resumen y Coincidencias; el nombre `registros` aplica a toda colección con ese nombre en la base); y `shift_image_counts` con lectura para `isAdmin()` y escritura negada (el bot usa el Admin SDK). Revisor y Sumador no leen nada de `image_reviews`. **Probado** en la zona de pruebas con las reglas publicadas: un usuario sin claim de admin NO puede leer un registro de `image_reviews` ni un documento de `shift_image_counts` (`get` denegado). **HECHO (verificado por el usuario el 2026-10-02)**: un admin real puede leer los registros (el Resumen real funcionó con una cuenta admin) y la consulta de grupo de colecciones funciona; el índice de grupo de colecciones sobre `fechaJornada` (ascendente) se creó desde la consola, como exención de `registros.fechaJornada`, con el enlace que trajo el error. **Pendiente**: un posible índice sobre `rol` para Coincidencias cuando haya ganadores; corregir el encabezado y republicar cuando cambie otra regla; validar `codigo` y `loteria` en las reglas; el desfase de claims (se leen solo al iniciar sesión); qué hacer con `functions/set-admin.js`, que reemplaza los claims sin fusionarlos.

**Regla de `winning_numbers` (PUBLICADA el 2026-10-02, verificado por el usuario)**: `match /winning_numbers/{docId}` con lectura para `isAdmin()` y escritura negada (la escribirá la función puente con el Admin SDK). Nombre y forma **PROVISIONALES**; la colección **todavía no existe**. El encabezado de `firestore.rules.draft` todavía dice que este bloque no está publicado: hay que corregirlo.

### Cloud Storage

Las imágenes/videos/audios se referencian por `storagePath` (nunca se guarda la URL completa en Firestore). La URL pública se construye en el cliente (`StorageDatasource.getDownloadUrl`) con el patrón:
`https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<path-encoded>?alt=media`

### Cloud Functions (`functions/index.js`, Node.js)

Todas las operaciones privilegiadas de gestión de usuarios pasan por Cloud Functions (nunca se tocan custom claims desde el cliente):

| Función | Qué hace |
|---|---|
| `createUser` | Crea un usuario de Firebase Auth + su doc en `users`. |
| `setUserRole` | Asigna/quita el custom claim `admin` (rol admin). |
| `updateUserPassword` | Cambia la contraseña de un usuario. |
| `deleteUser` | Elimina el usuario (Auth + Firestore). |
| `listUsers` | Lista todos los usuarios (para el panel de admin). |
| `toggleUserStatus` | Habilita/deshabilita el acceso de un usuario. |
| `updateUserGroups` | Actualiza `allowedGroups[]` de un usuario. |
| `listGroups` | Lista los grupos disponibles (`group_stats`) para asignar. |
| `setReviewRole` | Activa/cambia/desactiva el rol Revisor o Sumador de un usuario (claim simple `reviewRole`). Solo superAdmin. Si el rol cambia de verdad, limpia `reviewShifts` del usuario. |
| `updateReviewShifts` | Reemplaza la lista completa de (grupo, jornada) que cubre un Revisor/Sumador (`users/{uid}.reviewShifts`), con validación de unicidad por (rol, grupo, jornada). Solo superAdmin; exige que el usuario ya tenga `reviewRole`. **Ambas implementadas, probadas, con UI en `AdminPage` (`ReviewRoleDialog` + el botón "Horarios" de `AssignGroupsDialog`) y ya desplegadas a producción** — ver `.claude/skills/image-review-roles.md`. |

Se invocan desde Flutter con `FirebaseFunctions.instance.httpsCallable(name)`.

**Función puente de números ganadores (en construcción, por piezas)**: escribirá `winning_numbers/{fecha}` con los ganadores leídos de `whats-apuestas`. **Decidido por el usuario**: función programada **cada hora**; procesa **hoy y ayer en hora de Bogotá**, **sin historial**; **sin bot**; el número de `manual_lotteries` reemplaza al de `resultados_loterias` cuando es la misma lotería y la misma fecha, una lotería que solo está en la manual cuenta como una más y la serie se ignora. El usuario **autorizó** trabajar en `functions/` para esta función y desplegarla cuando esté lista.
- **Pieza b1 — HECHA**: `functions/winningNumbers.js`, función pura `mergeWinningNumbers(automaticDoc, manualList)` sin Firebase (no lee ni escribe, no está exportada en `index.js`), con tests en `functions/test/winningNumbers.test.js`. Devuelve `{ numbers, discarded }`: `numbers` son textos de exactamente 4 cifras (ceros a la izquierda conservados, sin duplicados, orden ascendente); `discarded` lista lo que no lo es (entero, vacío, otra longitud, caracteres que no son cifras) con su lotería, fuente y motivo. La forma de las entradas es **SUPOSICIÓN** (no hay ejemplos en el repo) y la clave para emparejar loterías (`lotteryKey`: slug en minúsculas, sin tildes y sin espacios sobrantes) es **PROVISIONAL**, a confirmar con datos reales.
- **Pendiente (no decidido)**: la clave de emparejamiento con datos reales; qué hacer con `discarded`; escribir siempre o solo si cambió; el handler programado (`onSchedule`, lecturas y escritura); el secreto con las credenciales de `whats-apuestas`; el deploy. Detalle en `.claude/skills/image-review-firebase-integration.md` ("Función puente de ganadores (pieza b)").

### Roles / custom claims

- `admin` y `superAdmin` son **custom claims** de Firebase Auth (no campos editables desde el cliente). Se leen en `mapToDomain` (`idTokenResult.claims`) al iniciar sesión.
- `AuthenticatedUser.isAdmin` / `.isSuperAdmin` gobiernan qué puede ver/hacer el usuario en la UI (acceso a `/admin`, botón para promover a admin, etc. — ver sección Admin).
- **`reviewRole`** (Revisor/Sumador del feature de revisión de imágenes): un **custom claim simple**, un string (`'revisor' | 'sumador' | ausente`), no un objeto — escrito por `setReviewRole` con el mismo patrón leer-fusionar-escribir que `setUserRole`. La exclusión mutua entre Revisor y Sumador es inherente (un solo valor posible). El **grupo y la jornada** que cada Revisor/Sumador cubre ya NO viven en el claim: es una **lista** en Firestore (`users/{uid}.reviewShifts: [{chatJid, shift}]`), escrita por `updateReviewShifts` — reemplazó al modelo anterior de "una sola asignación" (`reviewAssignment`) porque las cuentas reales cubren varios grupos a la vez, algunos repetidos entre personas del mismo rol en jornadas distintas. **Estado real: implementado, probado y desplegado a producción (backend + UI en `AdminPage`).** `AuthenticatedUser.reviewRole` ya lo lee (`mapToDomain`, mismo parseo defensivo que el resto de los claims) y es la fuente real de `currentReviewRoleProvider`; `reviewShifts` se lee aparte, en `reviewShiftsProvider` (lectura única, mismo patrón que `allowedGroups`), y condiciona si se muestra el formulario de captura por imagen — no es un filtrado de qué chats se ven. El `--dart-define=REVIEW_ROLE=...` sigue existiendo solo como fallback de desarrollo, para cuando no hay una sesión autenticada real. Detalle completo en `.claude/skills/image-review-roles.md`.

---

## 6. Rutas (`lib/app/router.dart`, go_router)

| Ruta | Pantalla | Guard |
|---|---|---|
| `/login` | `LoginPage` | Si ya está autenticado, redirige a `/home`. |
| `/home` | `HomePage` | Requiere sesión iniciada; si no, redirige a `/login`. |
| `/home/viewer/:initialIndex` | `ImageDetailPage` | Requiere sesión iniciada. `initialIndex` = índice inicial dentro de las imágenes del chat activo. |
| `/admin` | `AdminPage` | Requiere sesión iniciada **y** `isAdmin == true`; si no es admin, redirige a `/home`. |
| `/summary` | `SummaryPage` | Requiere sesión iniciada **y** (`isAdmin == true` **o** `isSuperAdmin == true`) (`canViewSummary`, decidido: Revisor y Sumador no la abren); si no, redirige a `/home`. La entrada "Resumen" del menú de `ChatList` solo la ven esas cuentas. Hoy sigue con datos INVENTADOS (ver sección 7.6). Pendiente: los claims se leen solo al iniciar sesión, así que a un admin al que le quiten el rol puede seguir viendo la pantalla hasta que se renueve el token. |
| `/matches` | `MatchesPage` | Requiere sesión iniciada **y** (`isAdmin == true` **o** `isSuperAdmin == true`) (`canViewMatches`); si no, redirige a `/home`. Lee datos REALES (ver sección 7.7); se abre desde el ítem "Coincidencias" del menú de `ChatList`. |

La decisión de redirect (a qué ruta mandar según sesión/rol) vive en `lib/app/auth_redirect.dart` (`computeAuthRedirect`), no inline en `router.dart` — se separó porque `router.dart` no se puede importar en un test de VM (arrastra `HomePage` → `MessageList`/`MessageBubble` → `package:web`, ver sección 10), y así el guard se puede testear sin GoRouter ni Firebase.

El router también escucha `authSessionProvider` y se refresca automáticamente cuando cambia el estado de sesión (login/logout), sin necesidad de navegación manual.

---

## 7. Features y pantallas

### 7.1 Auth (`lib/features/auth/`)

**Qué hace:** login por email/contraseña contra Firebase Auth; expone la sesión activa (`AuthSessionState`: `loading` / `authenticated(user)` / `unauthenticated`) al resto de la app.

**Pantalla: `LoginPage`** (`presentation/pages/login_page.dart`)
- Formulario con `CustomTextFormField` (email + contraseña con toggle de visibilidad).
- Gradiente de fondo (`AppColors.upLoginBackground` → `downLoginBackground`), tarjeta blanca centrada con logo.
- Estados: botón con spinner mientras `isLoading`; mensaje de error en rojo si falla el login (credenciales inválidas, usuario deshabilitado, etc., vía `AuthFailure` → `mapFailureToMessage`).
- Al loguearse OK, limpia el formulario; la navegación a `/home` la dispara el router (no la página).
- `ResponsiveLayout` con variantes mobile/desktop (tamaños de logo/fuente distintos, mismo comportamiento).

**Piezas clave:**
- `LoginFormNotifier` (`NotifierProvider`) — estado del formulario (email, password, loading, error) y `submit()`.
- `AuthSessionNotifier`/`authSessionProvider` — sesión global; se actualiza al hacer login (`setAuthenticated`) o logout.
- `FirebaseAuthDatasourceImpl` — llama a `signInWithEmailAndPassword`/`signOut`, traduce `FirebaseAuthException` a `AuthFailure`.
- `mapToDomain` — convierte el `User` de Firebase + sus custom claims (`admin`, `superAdmin`) en `AuthenticatedUser`.

---

### 7.2 Home / Chats (`lib/features/home/` + `lib/features/chats/`)

**Qué hace:** pantalla principal después de loguearse. Muestra la lista de grupos de WhatsApp que el usuario tiene permitido ver, permite buscarlos, y aloja la conversación seleccionada.

**Pantalla: `HomePage`** (`lib/features/home/presentation/pages/home_page.dart`)
- Layout responsive con **su propio breakpoint** (`AppBreakpoints.homeSplit = 700`, distinto del general de 600):
  - **Desktop (≥700px)**: panel dividido — `ChatList` a la izquierda (ancho `AppSizes.chatListWidth(screenWidth)`, entre 320–420px) y el panel de conversación a la derecha, separados por un `VerticalDivider`.
  - **Mobile (<700px)**: pantalla completa que alterna entre la lista de chats y la conversación activa (`AnimatedSwitcher`), con botón "Volver" en el header de la conversación.
- Sin chat seleccionado: muestra `CustomMessageGroup` (estado vacío ilustrado, "Selecciona un grupo para continuar").
- Con chat seleccionado: `ChatHeader` (nombre del grupo + badge de filtro de fecha activo + botón para abrir `ChatDrawer`) + `MessageList`.
- Al seleccionar un chat en mobile, la vista cambia automáticamente y limpia la búsqueda.

**Widget: `ChatList`** (`lib/features/chats/presentation/widgets/chat_list.dart`)
- Header propio ("Monitor de Imagenes" + menú de usuario `CustomPopupMenuLogoutButton`, con opción de ir al panel de admin si `isAdmin`, y cerrar sesión).
- Buscador (filtra por nombre de grupo, client-side, sobre los chats ya cargados).
- Lista principal (`ListView.builder`) de tiles de chat: avatar circular con inicial (color determinado por hash del nombre del grupo, paleta fija `_avatarColors`), nombre, hora del último mensaje, cantidad de mensajes (`totalImages`), animación de aparición (`ChatAppearAnimation`), hover/estado activo resaltado.
- Estados: shimmer de carga (`ChatsListLoading`), error (mensaje centrado), vacío (implícito si `allowedGroups` está vacío → lista vacía).
- Optimizado para rendimiento (`perf:` commits previos): widgets `const`, sin recomputar el color del avatar en cada build.

**Piezas clave:**
- `ChatsNotifier` (`AsyncNotifierProvider`) — carga inicial (`getChats`) + tiempo real (`listenChatUpdate`, con batching de 250 ms) + orden por `lastMessageAt` descendente.
- `activeChatProvider` — chat actualmente seleccionado (o `null`).
- `chatSearchQueryProvider` — texto de búsqueda.

---

### 7.3 Messages / Conversación (`lib/features/messages/`)

**Qué hace:** la feature más grande. Muestra los mensajes de un chat (texto, imágenes, video, audio), con filtro por fecha, estadísticas por jornada laboral, paginación y tiempo real; y el visor de imágenes a pantalla completa.

**Widget: `MessageList`** (`presentation/widgets/message_list.dart`)
- Lista invertida (más reciente abajo/visible primero) de `MessageBubble`, agrupadas con separadores de fecha (`formatDayLabel`) y ocultando el nombre del remitente si es consecutivo al mensaje anterior.
- Scroll infinito hacia atrás: al acercarse al final ya cargado, dispara `loadMore()` (páginas de 50).
- Botón flotante "ir al último mensaje" (`GoToLatestMessageButton`) que aparece al alejarse del final.
- Fondo con imagen decorativa (`assets/images/fondo.png`), estilo chat.
- Estados: shimmer (`MessageListLoading`, imita burbujas), vacío ("No hay mensajes aún"), error.

**Widget: `MessageBubble`** — una burbuja individual:
- Nombre del remitente (si aplica), preview de media (imagen con tap-to-abrir-visor, o botón "Ver video"/"Reproducir audio" que abre el archivo en pestaña nueva), texto/caption (`CustomRichText`), metadata (`MessageInformationWidget`: enviado por, jornada, fecha, # de imagen de la jornada, "Editado" si aplica), hora.
- Ancho máximo `AppSizes.messageBubbleMaxWidth` en desktop; ~92% del ancho de pantalla en mobile.

**Widget: `ChatHeader`** — barra superior de la conversación: nombre del grupo, badge del filtro de fecha activo (si no es el default "hoy y ayer"), botón para abrir el `ChatDrawer`.

**Widget: `ChatDrawer`** (panel lateral, "Panel de control"):
- Sección **Filtrar por fecha**: hoy y ayer (default), hoy, ayer, esta semana, día específico (`DatePicker` en web, bottom sheet con `CalendarDatePicker` en mobile/no-web).
- Sección **Imágenes por jornada**: cuenta de imágenes por cada `Shift` (turno laboral) del día, calculada sobre los mensajes ya cargados en memoria (`shiftStatsProvider`).
- El tiempo real (nuevos mensajes por listener) solo se activa si el filtro de fecha activo incluye el día de hoy (`DateFilter.includestoday`).

**Jornadas laborales** (`lib/core/time/shifts.dart`, enum `Shift`). Cada mensaje se clasifica en una jornada según su hora local al mapearse a dominio (`toDomain`); se trunca al minuto y el fin de cada rango es inclusivo. **Una sola tabla** (paso 7, pieza e), fija en código, para todas las fechas y todos los mensajes: el horario de la colección `jornadas` del proyecto `whats-apuestas` (DECIDIDO el 2026-09-30, sin lectura dinámica):
- Mañana (05:30–10:51), tarde 1 (10:58–13:55), tarde 2 (14:01–15:20), noche 1 (15:28–22:15), domingo/festivo (06:00–19:15, solo domingos), fuera de jornada.
- Los huecos entre jornadas (10:52–10:57, 13:56–14:00, 15:21–15:27) cuentan como fuera de jornada para reportes, pero en el visor se etiquetan "Fuera de jornada Mañana/Tarde 1/Tarde 2" y se agrupan junto a su jornada. Antes de 05:30, después de 22:15 y el domingo fuera de horario: "Fuera de las jornadas".
- **Se retiraron** la tabla vieja (06:00–10:54, …, noche 2 22:25–22:30) y el corte (`newShiftsEffectiveFromMs`). **Noche 2** (`night2`) solo queda como valor del enum (la usan el bot, `reviewShifts` y etiquetas guardadas): `getCurrentShift` nunca la devuelve, el diálogo de horarios no la ofrece y el panel de control no tiene su fila.
- **Etiquetas**: `shiftNames` tiene las etiquetas ACTUALES; las viejas están en `legacyShiftNames` y solo sirven para reconocer registros y documentos ya guardados (`shiftFromLabel`) y como respaldo de la etiqueta de noche 2. Las claves del enum no cambian.
- **Pendiente** (no decidido): actualizar el bot con los mismos rangos y sin noche 2 (en su repo; hasta entonces `shift_image_counts` sigue la tabla vieja y el "imágenes en la jornada" del Resumen puede estar desfasado en los bordes); retirar noche 2 de `ASSIGNABLE_SHIFTS` en `functions/`; fuente de festivos (hoy solo domingos); el horario del ERP puede cambiar sin aviso; caché de la PWA tras desplegar. Los mensajes ya guardados se reclasifican con la tabla única. Detalle en `.claude/skills/image-review-domain.md` ("Jornadas: una sola tabla").

**Pantalla: `ImageDetailPage`** (`presentation/viewer/image_detail_page.dart`) — visor de imágenes a pantalla completa:
- Navega entre todas las imágenes del chat activo (`chatImageItemsProvider`, derivado de los mensajes ya cargados que tienen media).
- Gestos tipo WhatsApp/Instagram, construidos sobre `ExtendedImageGesturePageView` + `ExtendedImage(mode: gesture)` (paquete `extended_image`, ya usado en el resto de la app):
  - Pinch-to-zoom y pan nativos, **estado de zoom independiente por imagen** (cada página tiene su propio `GlobalKey<ExtendedImageGestureState>`, no comparten un solo controller).
  - Mientras la imagen está con zoom (> 1.0), el pager **no cambia de imagen** al desplazar el dedo (`canScrollPage`) — solo hace pan dentro de la foto.
  - Doble tap / doble click = zoom centrado en el punto tocado (1.0 ↔ 2.5x).
  - Rueda del mouse = zoom (nativo del paquete).
  - La navegación es intencionalmente inversa (el `PageView` usa `reverse: true`, y así se pidió mantenerla): flecha izquierda / tecla ← = avanzar el índice; flecha derecha / tecla → = retroceder. Es la misma lógica de antes de la reescritura. Esc = cerrar; `+`/`-`/`0` = zoom in/out/reset (atajos de teclado, pensados para desktop).
  - Botones de zoom +/-/reset en la barra superior (mobile y desktop).
- Barra superior con info del mensaje (remitente, hora, jornada, # de imagen, "Editado"), variantes mobile/desktop.
- Indicador "X de N" abajo.
- Carga más mensajes automáticamente al acercarse al final de las imágenes disponibles.
- **Pendiente / fuera de alcance actual**: swipe-hacia-abajo-para-cerrar (tipo WhatsApp) — necesitaría que la ruta del visor sea transparente (cambios en `router.dart`), no implementado todavía.

**Piezas clave:**
- `MessagesNotifier` (`AsyncNotifierProvider`) — el más complejo: reacciona a cambios de chat activo o filtro de fecha (recarga desde cero), pagina por rango de fechas, enriquece mensajes con estado "editado" (cruce con `edit_attempts`, cacheado por id para no re-consultar), tiempo real con batching de 200 ms, orden estable (por timestamp desc, desempate por `shiftImageIndex`, luego por id).
- `dateFilterProvider` — filtro de fecha activo (`DateFilter`, unión sellada: hoy, ayer, hoy y ayer, esta semana, día específico).
- `shiftStatsProvider` — conteo de imágenes por jornada sobre los mensajes en memoria.
- `imageUrlProvider(storagePath)` — construye la URL pública de Storage.
- `chatImageItemsProvider` — deriva la lista de imágenes navegables para el visor a partir de los mensajes.

---

### 7.4 Admin (`lib/features/admin/`)

**Qué hace:** panel de administración para crear/gestionar usuarios y sus permisos. Solo accesible si `isAdmin == true` (guard de router).

**Pantalla: `AdminPage`** (`presentation/pages/admin_page.dart`)
- AppBar con título verde, botón volver, botón recargar.
- FAB "Nuevo usuario" que abre `CreateUserDialog`.
- Lista de usuarios (`_UserCard` por usuario), con transición animada entre estados (`AnimatedSwitcher`, ~400 ms) carga/vacío/datos.
- Cada `_UserCard` muestra: avatar (ícono admin o persona), email, badge de rol (Admin en verde / SuperAdmin en morado), switch de habilitado/deshabilitado, chips de grupos asignados, el rol de revisión actual ("Revisor"/"Sumador"/"Sin asignar revisión", solo visible para quien mira es `superAdmin`) y botones de acción:
  - **Cambiar contraseña** → `ChangePasswordDialog`.
  - **Asignar grupos** → `AssignGroupsDialog`.
  - **Hacer admin / Quitar admin** (solo visible para quien es `superAdmin`, y no aplica sobre otro `superAdmin`) → confirma en un diálogo y llama `setUserRole`.
  - **Rol de revisión** (solo visible para quien es `superAdmin`; a diferencia de "Hacer admin", SÍ aplica sobre otro `superAdmin` — Revisor/Sumador es independiente de admin/superAdmin) → abre `ReviewRoleDialog` y llama `setReviewRole`. Los horarios (grupo+jornada) ya no se editan acá: viven en `AssignGroupsDialog` ("Horarios" por grupo).
  - **Eliminar** (no aplica sobre un `superAdmin`) → confirma en un diálogo destructivo y llama `deleteUser`.
- Feedback de acciones vía `SnackBar` (verde éxito / rojo error), disparado por `ref.listen` sobre `adminProvider` + `clearMessages()`.

**Diálogos:**
- `CreateUserDialog` — nombre + contraseña (el email se genera como `<nombre>@gmail.com`, ver `_submit()` en el propio diálogo — convención específica de este proyecto, no un email real ingresado por el admin).
- `ChangePasswordDialog` — nueva contraseña para un usuario existente.
- `AssignGroupsDialog` — cada fila de grupo (`group_stats`) tiene un checkbox para marcar cuáles puede ver el usuario, más un botón "Horarios" que solo aparece si el grupo está marcado Y el usuario tiene `reviewRole` activo: abre `GroupShiftsDialog` (anidado, `showDialog` sobre `showDialog`) con las 6 jornadas asignables como checkboxes. Las jornadas ya cubiertas por OTRA persona del MISMO rol llegan deshabilitadas, con su email como subtítulo (usa `AdminState.users`, ya cargado, sin llamada extra) — así se coordina entre superAdmins antes de que el servidor rechace por conflicto. La selección de horarios por grupo vive en memoria (independiente de si el checkbox del grupo está marcado en ese instante) hasta que se pulsa "Guardar" en el diálogo padre, que llama `updateUserGroups` y, si hay `reviewRole`, también `updateReviewShifts` con las entradas de los grupos que siguen marcados.
- `ReviewRoleDialog` — Ninguno/Revisor/Sumador (radios, extraídos en `ReviewRoleRadioGroup` para reuso). Si el usuario ya tiene horarios asignados y el rol elegido es distinto del actual, advierte cuántos se van a borrar (el servidor limpia `reviewShifts` al cambiar de rol de verdad). Fire-and-forget como "Hacer admin": no espera la respuesta, cierra y confía en que `setReviewRole` es optimista y siempre recarga.

**Piezas clave:**
- `AdminNotifier` (`NotifierProvider<AdminState>`) — cachea `users` y `groups`, expone `isLoadingUsers/Groups`, `isSubmitting`, `error`, `successMessage`. Las mutaciones `toggleUserStatus`, `updateUserGroups`, `setUserRole` y `setReviewRole` actualizan el estado local **optimistamente** antes de llamar a la Cloud Function correspondiente; solo `toggleUserStatus` revierte el cambio local si falla, las demás recargan desde el servidor (`loadUsers()`) en vez de revertir a mano — `setReviewRole` lo hace SIEMPRE (éxito y fallo), porque cambiar de rol de verdad limpia `reviewShifts` en el servidor y el valor optimista no lo refleja. `updateReviewShifts` es la excepción NO optimista: espera la respuesta y devuelve el `Either<AdminFailure, Unit>` a quien la llama (además de actualizar `error`/`successMessage`), recargando también en ambos casos.
- `AdminRepository`/`AdminDatasourceImpl` — wrapper de las Cloud Functions (`createUser`, `deleteUser`, `listUsers`, `listGroups`, `toggleUserStatus`, `updateUserGroups`, `setUserRole`, `updatePassword`, `setReviewRole`, `updateReviewShifts`). `updateReviewShifts` mapea su `already-exists` a `AdminFailure.reviewShiftConflict(conflicts)` (con las tuplas en conflicto que manda el backend en `details`), aparte de `mapFunctionsException`, igual que `emailAlreadyExists` de `createUser`.

---

### 7.5 Revisión de imágenes (`lib/features/image_review/`)

**Qué hace:** formularios de captura para los roles Revisor y Sumador (comprobantes, números, totales de cada imagen), pensados para verificarse mutuamente por jornada. **En desarrollo activo, por capas** — no todo lo descrito abajo está conectado a Firebase todavía. Para el estado paso a paso, las reglas de negocio y las decisiones de diseño, ver `.claude/skills/image-review-workflow.md` (punto de entrada) y las demás skills `image-review-*`; acá solo el resumen de qué existe hoy.

- **Formulario de captura**: vive dentro de `ImageDetailPage` (visor de imágenes de la sección 7.3), como panel lateral exclusivo de pantallas anchas (`AppBreakpoints.reviewForm`), con rol activo asignado, y con esa imagen puntual cubierta por el `reviewShifts` de ese rol (tercera condición; no es un filtrado de qué chats se ven — `allowedGroups` no cambia). Bloquea la navegación entre imágenes hasta guardar el registro de la actual. Arriba, un solo campo **Código** (uno por foto, obligatorio para los dos roles); cada tarjeta de comprobante tiene números (solo Revisor), total y **"Lotería (opcional)"** (dónde se compró el boleto, sin relación con los ganadores ni la reconciliación). Un registro guardado antes del código por imagen se ve "Sin código", abre "Editar" con el código vacío y no se sube hasta volver a guardarlo (esquema local sigue en v1). **Pendiente**: validar `codigo` y `loteria` en las reglas (hoy no se validan); si la lotería pasa a ser una lista cerrada; un aviso visible para los registros viejos que no se pueden subir (la píldora los sigue contando).
- **Persistencia local**: con `hive_ce`, separada por usuario y por rol; sobrevive a recargar la app.
- **Subida**: un indicador por jornada con registros pendientes, subida manual por lote — **REAL a Firestore** (`FirestoreReviewUploader`; el uploader se construye solo al confirmar "Subir"). Las reglas se publicaron el 2026-10-01 y la primera escritura real funcionó (antes se rechazaba con `permission-denied` y los registros quedaban pendientes). Cada fallo deja un `debugPrint` con el messageId y el tipo de error. `SimulatedReviewUploader` queda sin cablear (candidato a borrar).
- **Rol activo**: `currentReviewRoleProvider` lee el custom claim `reviewRole` de `AuthenticatedUser` (sesión autenticada) como fuente real; `--dart-define=REVIEW_ROLE=revisor|sumador` queda solo como fallback de desarrollo para cuando no hay sesión real (ver sección 5).
- **Asignación de grupo + jornada**: `setReviewRole` (claim `reviewRole`) y `updateReviewShifts` (lista `reviewShifts` en Firestore, con validación de unicidad por rol+grupo+jornada) y su UI en `AdminPage` (sección 7.4) ya existen, están probadas y desplegadas a producción. `reviewShiftsProvider` lee esa lista (una vez, sin `.snapshots()`) y condiciona el formulario de captura de arriba.

### 7.6 Resumen (`lib/features/summary/`)

**Qué hace:** pantalla de reconciliación por jornada y grupo (compara lo registrado por Revisor y Sumador), en la ruta `/summary` (ver sección 6).

**Estado real: la pantalla lee datos REALES** (paso 7, pieza d): `summaryRepositoryProvider` devuelve `realSummaryRepositoryProvider` — registros de `image_reviews` (consulta de grupo de colecciones), contadores de `shift_image_counts` y nombres de `group_stats` —, solo para admin y superAdmin, con la caché de 5 minutos. **HECHO (verificado por el usuario el 2026-10-02)**: funciona con una cuenta admin; leyó los registros, los contadores y los nombres. `MockSummaryRepository` (escenarios inventados y deterministas por fecha) queda en el repo sin cablear: solo tests y referencia, candidato a borrar. Un error se ve en pantalla con el texto completo del `Failure` y "Reintentar"; además deja un `debugPrint` `[RESUMEN] falló (...)` (los errores de Firestore y de permisos con su texto completo, que si falta un índice trae el enlace para crearlo; los demás solo con el tipo). Coincidencias (7.7) también lee datos reales. Ver `.claude/skills/image-review-domain.md` para las reglas de reconciliación.

**Capa de datos real, conectada** (paso 7, pieza d, capa 1; nombres provisionales): `FirestoreSummaryRepository` y tres datasources en `features/summary/data/` — registros del día de todos los grupos (consulta de grupo de colecciones sobre `registros` por `fechaJornada`), contadores del bot del día (`shift_image_counts` por `shiftDate`) y nombre de cada grupo (`group_stats/{chatJid}`). Probada con datasources falsos; sus providers están en `real_summary_providers.dart`. Cómo agrega cada rol: `image-review-domain` § "Cómo se arma el Resumen real". El índice de grupo de colecciones sobre `fechaJornada` ya existe (2026-10-02). **Pendiente, no decidido**: borrar los 4 documentos de prueba antes de desplegar o de que otra persona use el Resumen; `lastIndex` puede ser mayor que las imágenes reales; el costo en lecturas por consulta (hasta unas 3600; la caché de 5 minutos evita repetirla).

**Caché del Resumen (activa, sobre el repositorio real)**: `SummaryCache` en memoria, por fecha: TTL de 5 minutos, solo resultados correctos (un error nunca se guarda), una sola lectura por fecha a la vez y máximo 10 fechas. Botón "Actualizar" en la barra superior (y "Reintentar" tras un error): invalida la fecha elegida y vuelve a la fuente. Los nombres de grupo se guardan toda la sesión, solo los encontrados (`CachedGroupNameDatasource`, aplicado en `real_summary_providers.dart`). **Pendiente**: la caché no se comparte entre pestañas ni sesiones; un registro subido después puede tardar hasta 5 minutos en aparecer (el botón lo evita);  `lastIndex` puede ser mayor que las imágenes reales.

**Aviso de imágenes sin registrar:** bajo cada rol de una jornada ya terminada, una línea informativa ("Faltan N imágenes por registrar") compara `imagenesEnJornada` (formato real de `shift_image_counts`) contra lo que registró ese rol. Es solo informativa y no altera el estado de dinero (cuadra/descuadre/pendiente).

El reloj del Resumen (`clockProvider`) se lee una vez por construcción de la lista: una jornada que termina con la pantalla abierta no muestra el aviso hasta que se reconstruya (por ejemplo, al cambiar la fecha).

### 7.7 Coincidencias (`lib/features/matches/`)

**Qué hace:** pantalla dedicada que cruza los números ganadores contra lo que registró el Revisor, organizados por fecha (selector de calendario, hoy por defecto) y jornada (nunca combinadas en un total del día), en la ruta `/matches` (ver sección 6). Acceso solo para `isAdmin`/`isSuperAdmin` (`canViewMatches`), independiente de `reviewRole`/`reviewShifts` y sin filtro por `allowedGroups`; se abre desde el ítem "Coincidencias" del menú de `ChatList`.

**Estado real: lee datos REALES** (paso 7, pieza c): `matchesRepositoryProvider` devuelve `realMatchesRepositoryProvider` (`FirestoreMatchesRepository`). Los ganadores de una fecha (`winning_numbers/{fecha}`, campo `numbers`; nombre y forma **PROVISIONALES**) se comparan contra los números del **Revisor** de TODAS las jornadas y grupos de esa fecha (consulta de grupo de colecciones sobre `registros` por `fechaJornada` y `rol`); solo cuenta el número. Cada coincidencia lee su mensaje (`whatsapp_messages`: quién lo envió y la hora) y el nombre de su grupo (`group_stats`, con la caché del Resumen; si no existe, el `chatJid`). Un error se ve en pantalla con "Reintentar" y deja un `debugPrint` `[COINCIDENCIAS] falló (...)` (misma política que el Resumen, `failureLogLine`). **HECHO (verificado por el usuario el 2026-10-02)**: la regla de lectura de `winning_numbers` está publicada y la pantalla abrió sin error con una cuenta admin, mostrando "Todavía no hay ganadores". La colección `winning_numbers` **todavía no existe**: la escribirá la función puente (decidida en `.claude/skills/image-review-firebase-integration.md`; solo la mezcla está hecha, ver sección 5). `MockMatchesRepository` queda sin cablear (solo tests y referencia, candidato a borrar). **Pendiente**: el handler, el secreto y el deploy de la función puente; el índice de grupo de colecciones sobre `fechaJornada` y `rol` (el enlace sale del error de la primera consulta con ganadores); caché; costo en lecturas; probar "Ver imagen" con una imagen real; borrar los mocks y el uploader simulado; borrar los 4 documentos de prueba antes de desplegar el hosting.

**Piezas clave:**
- `FirestoreMatchesRepository` (`data/repositories/`) y sus datasources (`data/datasources/`: registros del Revisor, ganadores del día y mensaje por id), cableados en `real_matches_providers.dart`; `MockMatchesRepository` (`data/`) sin cablear.
- `findMatches` (`domain/helpers/`) — igualdad exacta de `String` tras `trim`, sin normalizar (coherente con cómo el Revisor anota el número, `image-review-domain` regla 6); devuelve una entrada por registro coincidente, no por ganador.
- `canViewMatches` (`domain/helpers/`) — `isAdmin || isSuperAdmin`; la usan tanto el guard de `router.dart` (vía `lib/app/auth_redirect.dart`) como el ítem del menú, para que nunca diverjan.
- `matchesDateProvider`/`matchesRepositoryProvider`/`dayMatchesProvider` (`presentation/providers/`) — fecha activa, instancia del repositorio y las coincidencias del día elegido.
- `MatchesPage` (`presentation/pages/`) — estados carga/vacío/error, selector de fecha, siempre una `JornadaMatchesSection` por jornada (una jornada sin coincidencias dice "Todavía no hay ganadores"; el vacío de página solo aparece si el día no tiene jornadas).
- `MatchDetailDialog` (`presentation/widgets/`) — detalle de una coincidencia ("Ver más"), sin "Mensaje editado"; la imagen se pide bajo demanda al tocar "Ver imagen" (`realImageEnabled`, `true` por defecto; no se probó todavía con una imagen real).

**Limitaciones conocidas:**
- El repositorio real arma las jornadas del día (domingo: solo `holiday`); el mock, sin cablear, no modela los domingos.
- `MatchesPage` y `MatchDetailDialog` tienen dos ramas de `ResponsiveLayout` casi idénticas (igual que `SummaryPage`, sección 7.6); la diferencia real móvil/escritorio está solo en `_MatchTile` (dentro de `JornadaMatchesSection`) y su skeleton. Unificar esas ramas casi idénticas es un refactor pendiente, no hecho.
- `DayMatches.tieneGanador` significa "hubo coincidencia", no "hubo número ganador" — el vacío de página de `MatchesPage` usa `jornadas.isEmpty`, no ese getter.
- El texto "Editado" del visor (mensaje de WhatsApp editado, barra superior de `ImageDetailPage` — ver sección 7.3) y el chip de estado del registro de revisión (`ReviewStatusChip`, cuando el registro se re-guardó) coexisten con el mismo texto y color. Esta pantalla ya no muestra nada de "editado" (se quitó `messageEdited`).
- La altura del skeleton (`MatchesSkeleton`) se calibró con datos cortos (tolerancia de 12 px sobre una forma representativa); con un nombre de grupo de ~40 caracteres o un chatJid real, la sección en móvil puede salir algo más alta que esa aproximación.
- **Pruebas manuales pendientes**: un día con ganadores (cuando exista `winning_numbers`), un domingo, "Ver imagen" con una imagen real, y anchos de 360, ~750 y 1280 px.
- **Recordatorio**: borrar los 4 documentos de prueba antes de desplegar el hosting.

---

## 8. Convenciones importantes para nuevas features

- **Nunca lanzar excepciones desde `data`/`domain`** — siempre `Either<Failure, T>`.
- **Nunca setear custom claims (`admin`/`superAdmin`) desde el cliente** — todo pasa por Cloud Functions.
- **Nunca reemplazar el objeto completo de custom claims de un usuario** (`admin.auth().setCustomUserClaims`) **sin leer antes los claims existentes** con `getUser()` y fusionar — hacerlo sin merge borra silenciosamente cualquier otro claim que el usuario tuviera (bug real, corregido en `functions/index.js`, `setUserRole`; el mismo patrón se repite en `setReviewRole`).
- **Nunca guardar URLs completas de Storage en Firestore** — solo `storagePath`; la URL se construye en el cliente.
- **Todo texto de UI en español**, incluyendo tooltips, vacíos y errores (los errores salen de `mapFailureToMessage`/`failure.message`, no se inventan strings sueltos).
- **Un solo sistema de breakpoints** (`AppBreakpoints`) — si una pantalla nueva necesita un umbral propio (como `homeSplit`), se agrega ahí con su razón documentada, no como constante local.
- **Reusar tokens de `core/theme/`** antes de escribir un número mágico de espaciado/radio/color/duración.
- **El `ThemeData` global (`AppTheme.light`) ya define los estilos comunes** de botones/diálogos/inputs — no repetir `style`/`shape`/`color` en un widget si coincide con el default del tema.
- Ver `.claude/skills/ui-design/SKILL.md` para el detalle completo de patrones de UI (estados carga/vacío/error, estructura de una página nueva, checklist).

## 9. Comandos útiles

```bash
flutter pub get
flutter run
flutter pub run build_runner build --delete-conflicting-outputs   # tras editar @freezed/@riverpod
flutter analyze
flutter test
flutter build web && firebase deploy --only hosting

# Firebase Functions (desde functions/)
npm run serve   # emulador local
npm run deploy
npm run logs
npm test        # node:test + mocks del Admin SDK, sin dependencias nuevas
```

## 10. Deuda técnica / notas conocidas

- `flutter test` falla en `message_bubble_test.dart` y `message_list_test.dart` por un problema de compatibilidad de `package:web` con el runner de tests en la VM de Dart (no afecta `flutter build web`, que compila limpio — confirmado). Causa: `message_bubble.dart` importa `package:web/web.dart` sin condicionar por plataforma, y esa librería solo funciona en targets web reales (dart2js/dartdevc/wasm), no en la VM. Si algún día se compila esta app para Android/iOS/Windows/macOS/Linux (las carpetas de esas plataformas existen en el repo), ese mismo import probablemente rompería la compilación ahí — pendiente de envolver con un import condicional o `kIsWeb`.
- Swipe-hacia-abajo-para-cerrar en el visor de imágenes: no implementado (ver sección 7.3).
- No hay `firestore.rules` ni `storage.rules` desplegables en el repo; `firestore.rules.draft` es solo la copia de lo publicado a mano en la consola (2026-10-01), sin referenciar en `firebase.json` y con el comentario del encabezado desactualizado (ver sección 5).
- No hay configuración de emuladores de Firebase: ni bloque `emulators` en `firebase.json`, ni cableado en Flutter para apuntar a un emulador local. Probar Cloud Functions hoy significa mocks del Admin SDK (`functions/test/`) o pruebas cuidadosas contra producción con cuentas de prueba.
- `firebase-functions` está desactualizada en producción (`7.2.5`); la actualización a `7.4.0` ya está commiteada en `functions/package.json` pero no desplegada — pendiente de juntarse con el próximo deploy real de `functions/` (el de `setReviewRole`/`updateReviewShifts`).
- La lista `reviewShifts` guarda la jornada por el identificador del enum Dart (p. ej. `afternoon1`), mientras los registros del feature de revisión de imágenes guardan la etiqueta en español (p. ej. "Jornada Tarde 1 (10:55 – 13:58)") — hará falta un mapeo entre ambos al implementar el filtrado por asignación (ver `.claude/skills/image-review-roles.md`).
- `updateReviewShifts` valida la unicidad de (rol, grupo, jornada) leyendo `listUsers(1000)` + `getAll` batcheado de Firestore, sin transacción entre el chequeo y la escritura — riesgo aceptado para una acción manual y poco frecuente (dos superAdmins asignando al mismo tiempo podrían duplicar la tupla), no resuelto con infraestructura nueva.
- `pubspec.yaml` declara `cached_network_image` y `json_serializable` como dependencias, pero no se encontró ningún uso de ninguna de las dos en `lib/` (ni `CachedNetworkImage`, ni `@JsonSerializable`/archivos `.g.dart` generados) — posibles dependencias sin usar, a confirmar antes de quitarlas.
