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
| `users` | `uid`, `email`, `allowedGroups[]`, `isAdmin`, `isSuperAdmin`, `disabled` | Perfil + permisos de cada usuario de la app. `allowedGroups` determina qué chats puede ver. |
| `group_stats` | `chatJid`, `groupName`, `lastMessageAt`, `totalImages` | Metadata de cada grupo de WhatsApp monitoreado (una fila por grupo). Fuente de la lista de chats. |
| `whatsapp_messages` | `chatJid`, `senderName`, `messageTimestamp`, `caption`, `hasMedia`, `storagePath`, `isEdited`, `messageDate`, `localTime`, `shiftImageIndex` | Cada mensaje del grupo (texto y/o imagen/video/audio). |
| `edit_attempts` | (por `messageId`) | Auditoría de intentos de edición de un mensaje de WhatsApp; se usa para marcar mensajes como "Editado" en la UI. |

**Filtrado de chats por permisos**: no es una regla de seguridad automática vía Firestore rules solamente — el datasource (`ChatsFirestoreDatasource`) lee `users/{uid}.allowedGroups` y hace queries `whereIn` sobre `group_stats.chatJid` (en chunks de 30, porque `whereIn` de Firestore tiene ese límite). Si `allowedGroups` está vacío, no se muestra ningún chat.

**Paginación de mensajes**: cursor-based con `startAfterDocument` sobre `whatsapp_messages`, ordenado por `messageTimestamp desc` + `documentId desc` como desempate. Tamaño de página: 50. El filtro de fecha (`DateFilter`) acota el rango con `where messageTimestamp >= from AND < to`.

**Tiempo real**: mientras el filtro de fecha activo incluya "hoy", se abre un listener (`snapshots()`) que escucha solo documentos añadidos con `messageTimestamp` mayor al último conocido, y los mensajes nuevos se agrupan (batching con `Timer` de 200 ms) antes de insertarlos al principio de la lista — evita animar/reordenar en cada mensaje individual si llegan varios juntos.

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

Se invocan desde Flutter con `FirebaseFunctions.instance.httpsCallable(name)`.

### Roles / custom claims

- `admin` y `superAdmin` son **custom claims** de Firebase Auth (no campos editables desde el cliente). Se leen en `mapToDomain` (`idTokenResult.claims`) al iniciar sesión.
- `AuthenticatedUser.isAdmin` / `.isSuperAdmin` gobiernan qué puede ver/hacer el usuario en la UI (acceso a `/admin`, botón para promover a admin, etc. — ver sección Admin).

---

## 6. Rutas (`lib/app/router.dart`, go_router)

| Ruta | Pantalla | Guard |
|---|---|---|
| `/login` | `LoginPage` | Si ya está autenticado, redirige a `/home`. |
| `/home` | `HomePage` | Requiere sesión iniciada; si no, redirige a `/login`. |
| `/home/viewer/:initialIndex` | `ImageDetailPage` | Requiere sesión iniciada. `initialIndex` = índice inicial dentro de las imágenes del chat activo. |
| `/admin` | `AdminPage` | Requiere sesión iniciada **y** `isAdmin == true`; si no es admin, redirige a `/home`. |

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

**Jornadas laborales** (`lib/core/time/shifts.dart`, enum `Shift`): mañana (06:00–10:54), tarde 1 (10:55–13:58), tarde 2 (13:59–15:23), noche 1 (15:24–22:24), noche 2 (22:25–22:30), domingo/festivo (06:00–19:20), fuera de jornada. Cada mensaje se clasifica en una jornada según su hora local al mapearse a dominio (`toDomain`).

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
- Cada `_UserCard` muestra: avatar (ícono admin o persona), email, badge de rol (Admin en verde / SuperAdmin en morado), switch de habilitado/deshabilitado, chips de grupos asignados, y botones de acción:
  - **Cambiar contraseña** → `ChangePasswordDialog`.
  - **Asignar grupos** → `AssignGroupsDialog`.
  - **Hacer admin / Quitar admin** (solo visible para quien es `superAdmin`, y no aplica sobre otro `superAdmin`) → confirma en un diálogo y llama `setUserRole`.
  - **Eliminar** (no aplica sobre un `superAdmin`) → confirma en un diálogo destructivo y llama `deleteUser`.
- Feedback de acciones vía `SnackBar` (verde éxito / rojo error), disparado por `ref.listen` sobre `adminProvider` + `clearMessages()`.

**Diálogos:**
- `CreateUserDialog` — nombre + contraseña (el email se genera como `<nombre>@gmail.com`, ver `_submit()` en el propio diálogo — convención específica de este proyecto, no un email real ingresado por el admin).
- `ChangePasswordDialog` — nueva contraseña para un usuario existente.
- `AssignGroupsDialog` — checklist de grupos (`group_stats`) para marcar cuáles puede ver el usuario.

**Piezas clave:**
- `AdminNotifier` (`NotifierProvider<AdminState>`) — cachea `users` y `groups`, expone `isLoadingUsers/Groups`, `isSubmitting`, `error`, `successMessage`. Todas las mutaciones (`toggleUserStatus`, `updateUserGroups`, `setUserRole`) actualizan el estado local **optimistamente** antes de llamar a la Cloud Function correspondiente, y revierten (o recargan desde el servidor) si falla.
- `AdminRepository`/`AdminDatasourceImpl` — wrapper de las Cloud Functions (`createUser`, `deleteUser`, `listUsers`, `listGroups`, `toggleUserStatus`, `updateUserGroups`, `setUserRole`, `updatePassword`).

---

## 8. Convenciones importantes para nuevas features

- **Nunca lanzar excepciones desde `data`/`domain`** — siempre `Either<Failure, T>`.
- **Nunca setear custom claims (`admin`/`superAdmin`) desde el cliente** — todo pasa por Cloud Functions.
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
```

## 10. Deuda técnica / notas conocidas

- `flutter test` falla en `message_bubble_test.dart` y `message_list_test.dart` por un problema de compatibilidad de `package:web` con el runner de tests en la VM de Dart (no afecta `flutter build web`, que compila limpio — confirmado). Causa: `message_bubble.dart` importa `package:web/web.dart` sin condicionar por plataforma, y esa librería solo funciona en targets web reales (dart2js/dartdevc/wasm), no en la VM. Si algún día se compila esta app para Android/iOS/Windows/macOS/Linux (las carpetas de esas plataformas existen en el repo), ese mismo import probablemente rompería la compilación ahí — pendiente de envolver con un import condicional o `kIsWeb`.
- Swipe-hacia-abajo-para-cerrar en el visor de imágenes: no implementado (ver sección 7.3).
