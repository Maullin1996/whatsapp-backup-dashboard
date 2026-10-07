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
| `image_reviews` **(PROVISIONAL)** | Estructura grupo -> jornada -> registros: `image_reviews/{chatJid}/jornadas/{fechaJornada}_{shiftKey}/registros/{messageId}_{rol}`. Cada registro: `messageId`, `chatJid`, `shift` (etiqueta), `shiftKey` (nombre del enum), `rol`, `storagePath`, `fechaJornada`, `messageTimestamp` (int, ms UTC del mensaje, tal cual), `codigo` (uno por imagen), `comprobantes[]` (cada uno `{numeros, total, loteria}`; `loteria` es el identificador de la lista cerrada de 43, obligatorio al guardar; un registro viejo trae texto libre o null), `anotaciones`, `registradoEn`, `registradoPor`, `editado` | Registros de Revisor/Sumador del feature de revisión de imágenes. **La subida es real** (`FirestoreReviewUploader`, cableado en `reviewUploaderProvider`) y las reglas de escritura y de lectura de admin **están publicadas desde el 2026-10-01** (copia en `firestore.rules.draft`, ver abajo). La primera escritura real ya se hizo: había 4 documentos de PRUEBA, **borrados por el usuario desde la consola el 2026-10-04** (ver abajo). Nombres definitivos y conectar las lecturas siguen pendientes — ver `.claude/skills/image-review-offline-sync.md` § "Ruta de la subida". |
| `jornadas` **(PROVISIONAL)** | Ids `festivos`, `manana`, `tarde_1`, `tarde_2`, `noche`; campos `name`, `startTime`, `endTime`, `pendingApproval`, `proposedBy`, `proposedStartTime`, `proposedEndTime` | Réplica exacta de la colección `jornadas` del ERP (`whats-apuestas`), copiada por la función programada (horarios dinámicos, pieza 1, **desplegada entre el 2026-10-03 y la madrugada del 2026-10-04**, dato del usuario, dentro de `syncWinningNumbers`). Colección de la raíz, distinta de las subcolecciones `image_reviews/{chatJid}/jornadas`. La app la lee desde la pieza 2 (ver sección 7.3), su regla de lectura está **PUBLICADA** (confirmado por el usuario el 2026-10-04), y la colección existe en nuestro proyecto con los 5 documentos (`festivos`, `manana`, `noche`, `tarde_1`, `tarde_2`; dato del usuario); el log de cada corrida trae el resumen `[JORNADAS] resumen`. La tabla fija sigue como respaldo. Ver sección "Cloud Functions". |
| `festivos_colombia` **(PROVISIONAL)** | Diez documentos, ids `"2026"` a `"2035"`; un solo campo `fechas` (lista de textos `yyyy-MM-dd`, ordenada, sin repetidas; 18 por año, 2030 con 17) | Festivos legales de Colombia. **Cargados el 2026-10-03** con el Admin SDK (`set` completo) desde una lista generada con reglas y revisada por el usuario, y verificados releyéndolos. Los lee la app (pieza 2, sección 7.3); su regla de lectura está **PUBLICADA** (confirmado por el usuario el 2026-10-04). |

**Filtrado de chats por permisos**: no es una regla de seguridad automática vía Firestore rules solamente — el datasource (`ChatsFirestoreDatasource`) lee `users/{uid}.allowedGroups` y hace queries `whereIn` sobre `group_stats.chatJid` (en chunks de 30, porque `whereIn` de Firestore tiene ese límite). Si `allowedGroups` está vacío, no se muestra ningún chat.

**Paginación de mensajes**: cursor-based con `startAfterDocument` sobre `whatsapp_messages`, ordenado por `messageTimestamp desc` + `documentId desc` como desempate. Tamaño de página: 50. El filtro de fecha (`DateFilter`) acota el rango con `where messageTimestamp >= from AND < to`.

**Tiempo real**: mientras el filtro de fecha activo incluya "hoy", se abre un listener (`snapshots()`) que escucha solo documentos añadidos con `messageTimestamp` mayor al último conocido, y los mensajes nuevos se agrupan (batching con `Timer` de 200 ms) antes de insertarlos al principio de la lista — evita animar/reordenar en cada mensaje individual si llegan varios juntos.

**Reglas versionadas solo como copia**: no hay `firestore.rules` ni `storage.rules` desplegables en el proyecto. Las reglas de Firestore se publican a mano en la consola y `firestore.rules.draft` es la copia de lo publicado (ver abajo); las de Storage no están en el repo, así que sus permisos no se pueden confirmar desde el código.

**Reglas de Firestore (`firestore.rules.draft`, copia de lo PUBLICADO)**: **publicadas en la consola** (HECHO, verificado por el usuario el 2026-10-01; versión vigente de ese día, 7:37 p.m.). El archivo está en la raíz del repo pero **no se referencia en `firebase.json`** (no hay bloque `firestore`) ni se despliega con la CLI. Se publica a mano pegándolo en la consola de Firebase, lo que reemplaza todo el conjunto de reglas; por eso empieza con una copia exacta de las reglas que ya había en la consola, sin cambios (`whatsapp_messages`, `group_stats`, `edit_attempts`: lectura con sesión, escritura negada; `users/{uid}`: lectura del propio uid, escritura negada). Agrega `create`/`update` de `image_reviews/{chatJid}/jornadas/{jornadaId}/registros/{registroId}` (delete negado): sesión, claim `reviewRole` igual al `rol` del documento, ids coherentes con el payload, `shiftKey` asignable, tipos de las claves y `messageTimestamp`/`chatJid` iguales a los de `whatsapp_messages/{messageId}`. Antes de publicar se probó en parte en la zona de pruebas (claim simulado; detalle en `.claude/skills/image-review-offline-sync.md`). Cada publicación requiere autorización explícita y comprobar antes que las reglas de la consola no cambiaron.

**Primera escritura real (HECHO, 2026-10-01)**: 4 documentos de **PRUEBA** en la base de producción, en 2 jornadas del 2026-10-01 (`2026-10-01_afternoon2` y `2026-10-01_night1`), con Revisor y Sumador en cada una, escritos con dos cuentas distintas. Confirmado en la consola: la ruta; `codigo` arriba; cada comprobante `{numeros, total, loteria}` (`loteria` null si quedó vacía); el Sumador con `numeros` vacío; `registradoEn` como texto; `total` como int64; `messageTimestamp` como entero; ceros a la izquierda conservados; `fechaJornada` y `shiftKey` coherentes con la hora del mensaje en hora de Colombia. También verificado: el claim `reviewRole` real se evalúa bien para los dos roles y la comparación de `messageTimestamp`/`chatJid` contra `whatsapp_messages` funciona con mensajes reales. Esos 4 documentos de prueba fueron **borrados por el usuario desde la consola el 2026-10-04**.

**Reglas de lectura de admin (publicadas el 2026-10-01)**: `isAdmin()` (sesión y claim `admin` o `superAdmin` en `true`, leídos con `token.get(..., false)`); `match /{path=**}/registros/{registroId}` con solo lectura para `isAdmin()` (el comodín recursivo es el que exige la consulta de grupo de colecciones del Resumen y Coincidencias; el nombre `registros` aplica a toda colección con ese nombre en la base); y `shift_image_counts` con lectura para `isAdmin()` y escritura negada (el bot usa el Admin SDK). Revisor y Sumador no leen nada de `image_reviews`. **Probado** en la zona de pruebas con las reglas publicadas: un usuario sin claim de admin NO puede leer un registro de `image_reviews` ni un documento de `shift_image_counts` (`get` denegado). **HECHO (verificado por el usuario el 2026-10-02)**: un admin real puede leer los registros (el Resumen real funcionó con una cuenta admin) y la consulta de grupo de colecciones funciona; el índice de grupo de colecciones sobre `fechaJornada` (ascendente) se creó desde la consola, como exención de `registros.fechaJornada`, con el enlace que trajo el error. **Pendiente**: un posible índice sobre `rol` para Coincidencias cuando haya ganadores; validar `codigo` y `loteria` en las reglas; el desfase de claims (se leen solo al iniciar sesión). **`functions/set-admin.js` — HECHO**: ahora fusiona los claims existentes (`{...claimsActuales, admin: true, superAdmin: true}`, leídos del `UserRecord` de `getUserByEmail`) en vez de reemplazarlos, así que ya no borra `reviewRole`; tests en `functions/test/setAdmin.test.js`. **SUPOSICIÓN**: un claim que ya se hubiera perdido por una corrida anterior del script no se recupera solo.

**Regla de `winning_numbers` (PUBLICADA el 2026-10-02, verificado por el usuario)**: `match /winning_numbers/{docId}` con lectura para `isAdmin()` y escritura negada (la escribirá la función puente con el Admin SDK). Nombre y forma **PROVISIONALES**; la colección existe desde el 2026-10-03 (la escribe la función puente desplegada, ver más abajo).

**Regla de `jornadas` (PUBLICADA el 2026-10-04, confirmado por el usuario)**: `match /jornadas/{docId}` con lectura para cualquier usuario con sesión y escritura negada (la escribe la función programada con el Admin SDK). Está en `firestore.rules.draft`, marcada PUBLICADO.

**Regla de `festivos_colombia` (PUBLICADA el 2026-10-04, confirmado por el usuario)**: `match /festivos_colombia/{docId}`, igual a la de `jornadas` (lectura con sesión, escritura negada), en `firestore.rules.draft` marcada PUBLICADO. Se publicó el borrador completo a mano (publicar reemplaza todo el conjunto).

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

**Función puente de números ganadores (DESPLEGADA el 2026-10-03 y vuelta a desplegar con la copia de `jornadas`, los alias y la pieza b3, dato del usuario; corre cada hora)**: escribe `winning_numbers/{fecha}` con los ganadores leídos de `whats-apuestas`. **Decidido por el usuario**: función programada **cada hora**; procesa **hoy y ayer en hora de Bogotá**, **sin historial**; **sin bot**; el número de `manual_lotteries` reemplaza al de `resultados_loterias` cuando es la misma lotería y la misma fecha, una lotería que solo está en la manual cuenta como una más y la serie se ignora. El usuario **autorizó** trabajar en `functions/` para esta función y desplegarla cuando esté lista.
- **Pieza b1 — HECHA**: `functions/winningNumbers.js`, función pura `mergeWinningNumbers(automaticDoc, manualList)` sin Firebase (no lee ni escribe, no está exportada en `index.js`), con tests en `functions/test/winningNumbers.test.js`. Devuelve `{ numbers, discarded }`: `numbers` son textos de exactamente 3 o 4 cifras (ceros a la izquierda conservados, "606" y "0606" distintos, sin duplicados, orden ascendente); `discarded` lista lo que no lo es (entero, vacío, otra longitud, caracteres que no son cifras, o sin nombre ni slug de lotería: `sin-loteria`) con su lotería, fuente y motivo. La clave para emparejar loterías (`lotteryKey`: slug en minúsculas, sin tildes y sin espacios sobrantes) es **PROVISIONAL**.
- **Pieza b1.1 — HECHA** (solo lógica pura y tests con datos falsos): la forma de las entradas se vio en datos reales; el handler le pasará `doc.data().list` de `manual_lotteries/{yyyy-MM-dd}` (un documento por fecha con un campo `list`; el `date` de cada elemento no se usa). **Decidido por el usuario**: se aceptan ganadores de 3 o 4 cifras ("Cash three" cuenta, en el mismo `numbers`); una entrada sin nombre ni slug no es válida; el slug sigue como clave PROVISIONAL; la escritura será solo si cambió (en el handler, pieza b2). **Regla de comparación de `findMatches` (boletos de 2, 3 y 4 cifras), decidida por el usuario (aclaración del cliente) e IMPLEMENTADA** (ver sección 7.7): con un ganador de 4 cifras, un boleto de 4 gana si es igual al ganador completo, uno de 3 si es igual a sus últimas 3 y uno de 2 si es igual a sus últimas 2; con un ganador de 3 cifras, un boleto de 3 gana si es igual al ganador completo y uno de 2 si es igual a sus últimas 2; un boleto de 4 nunca coincide con un ganador de 3; boletos de otra longitud y ganadores de longitud distinta de 3 o 4 se ignoran sin aviso; si un mismo ganador acierta a boletos de distinta longitud, se muestran como coincidencias separadas; un boleto puede coincidir a la vez con varios ganadores ("606" con "606" y con "4606"): la app solo muestra coincidencias y los revisores deciden si corresponde el premio doble. La función puente no cambia: los ganadores siguen siendo de 3 o 4 cifras. **Decidido también**: si el resultado de una fecha sale vacío, el handler (pieza b2) no escribe nada y deja lo que había (si se borran los ganadores, los revisores no los revisan). **HECHO**: `findMatches` devuelve una entrada por registro coincidente (la entrada no lleva el ganador), así que un boleto que acierta a dos ganadores sale una sola vez. **Decidido por el usuario e IMPLEMENTADO — alias `doramaña` → `dorado_mañana`**: `lotteryKey` normaliza y después aplica la tabla `LOTTERY_KEY_ALIASES` (una sola entrada), a las entradas de las dos fuentes, así que la manual `doramaña` reemplaza a la automática `dorado_mañana`. Respaldo: en una lectura de `whats-apuestas` del 2026-10-03, `doramaña` coincide con `dorado_mañana` en 118 fechas entre 2026-01-19 y 2026-10-03. Se descarta el resto de los pares por aparecer en una sola fecha; `doradotarde` y `dorado_tarde` no se emparejan.
- **Pieza b2 — HECHA** (código y tests con datos falsos; desplegada el 2026-10-03, ver abajo). **Decidido por el usuario**: disparador cada 60 minutos, hoy y ayer en hora de Bogotá, escribir solo si cambió, un resultado vacío no escribe nada (deja lo que había). Sobre `discarded`: comportamiento actual de la pieza b2: discarded solo se registra en el log; qué hacer con discarded sigue PENDIENTE (no decidido). `functions/winningNumbersSync.js` (sin `firebase-admin`; lecturas, escritura, logger y hora por parámetro): `syncWinningNumbers` lee `resultados_loterias/{fecha}` y `manual_lotteries/{fecha}` (ausente = vacío), mezcla con `mergeWinningNumbers` (sin cambios), compara con `winning_numbers/{fecha}` como listas ordenadas y escribe `{numbers}` solo si cambió o no existe; una fecha que falla se registra con su id y el tipo de error, no se escribe y se sigue con la otra; devuelve y registra un resumen por fecha (`escrita`, `sin-cambios`, `omitida-vacia`, `error`). La fecha de Bogotá se calcula con UTC-5 fijo. `runWinningNumbersSync` lee y parsea el secreto (si falta o no es JSON, registra el error con el nombre del secreto, nunca su contenido, y no escribe). En `functions/index.js` solo se agregaron los imports y el export `syncWinningNumbers`: `onSchedule` con `schedule: "every 60 minutes"`, `timeZone: "America/Bogota"`, sin región y `secrets: [defineSecret("WHATS_APUESTAS_KEY")]` (nombre **PROVISIONAL**, una sola constante; que Cloud Scheduler acepte `"every 60 minutes"` quedó **CONFIRMADO** con el deploy); el wrapper crea una segunda app de Admin (`"whats-apuestas"`) para leer las dos colecciones y usa la app por defecto para `winning_numbers`. Tests en `functions/test/winningNumbersSync.test.js`. **SUPOSICIÓN**: el documento lleva solo `numbers`.
- **Deploy — HECHO (verificado por el usuario el 2026-10-03)**: secreto `WHATS_APUESTAS_KEY` creado en `whatsapp-pro-3d483` (versión 1). Deploy con `firebase deploy --only functions:syncWinningNumbers` (solo esa función, sin `--force`) hacia las 00:39 de Bogotá: `syncWinningNumbers` v2 programada, `us-central1`, 256 MB, `nodejs24`; el CLI habilitó Cloud Scheduler y dio acceso al secreto a la cuenta de servicio de Compute por defecto. Los 10 callables no se redesplegaron (`functions:list` los muestra intactos) y `setReviewAssignment` ya no está en producción. Primera corrida (forzada desde Cloud Scheduler a las 00:44): `escrita` para 2026-10-03 y 2026-10-02, sin errores; la llave lee el ERP y la función escribe `winning_numbers` con el formato esperado (lista de textos, ceros a la izquierda, "606" incluido, orden de texto); la entrada manual vacía del 2026-10-02 se descartó con `sin-loteria` y no se publicó. El cron corre solo (02:44, 03:44 y 04:44 de Bogotá, `sin-cambios` en las dos fechas): queda **CONFIRMADO** que Cloud Scheduler acepta `"every 60 minutes"`. El aviso `[GANADORES] descartado ... sin-loteria` se repite en cada corrida mientras exista esa entrada manual vacía (esperado, no afecta nada).
- **Decidido por el usuario — plazo de los resultados**: los resultados del día D valen hasta las 5:30 a.m. (Bogotá) del día D+1; desde esa hora cuentan para el día nuevo. La función no cambia (procesa hoy y ayer en cada corrida) y no se agrega ninguna regla de horas.
- **Observado (HECHO, sin explicar la causa)**, lecturas únicas de solo lectura de `whats-apuestas` del 2026-10-03: en una lectura de ese día, 258 de 259 documentos de `resultados_loterias` tienen su última actualización a las 13:30 de Bogotá, y cada documento se crea a las 20:30 del día anterior. `resultados_loterias/2026-10-03` tuvo 20 entradas a las 20:30, 32 a las 06:30 y 9 a las 13:30: la actualización de las 13:30 reemplaza el contenido (corrige la nota anterior de 20 entradas); `resultados_loterias/2026-10-02` quedó con `updatedAt` a las 13:30 y 9 entradas; `manual_lotteries/2026-10-03` no existía en la primera lectura. Por eso, antes de las 13:30, `winning_numbers/2026-10-03` contenía resultados de otra jornada, y `winning_numbers/2026-10-02` tiene solo los 9 de las 13:30. "Play four día" figuraba como 5362 en una lectura anterior y como 9252 después, sin explicación (según el usuario la API "a veces se equivoca"; no verificado). **SUPOSICIÓN** (nadie la verificó): que quien escribe `resultados_loterias` arma el id con la fecha en UTC.
- **Pieza b3 — cada ganador con su lotería (HECHA el 2026-10-05, DESPLEGADA entre el 2026-10-05 y el 2026-10-06, deducido de la conversación, sin confirmar)**: **decidido por el usuario**: cada número registrado llevará su lotería y un ganador solo coincidirá con un número de la misma lotería (con la regla de 2, 3 y 4 cifras). La función puente escribe ahora `winning_numbers/{fecha}` con `numbers` (lista de textos, como siempre) **y** `entries` (lista de `{loteria, numero}`): `mergeWinningNumbers` devuelve `entries` (la lotería es la clave de `lotteryKey` con alias, sin duplicados por pareja, ordenada por lotería y número) y `syncWinningNumbers` compara contra lo guardado incluyendo `entries`, así que los documentos de hoy y ayer se reescriben una vez al desplegar. Alias nuevos decididos por el usuario: `doradotarde` → `dorado_tarde`, `doradonoche` → `dorado_noche`, `pija0`/`pijao`/`pijo` → `pijao_de_oro` (más `doramaña` → `dorado_manana`, con 119 fechas de coincidencia por número; los demás sin prueba por número). Lista cerrada del selector (la define la app, en otra pieza), 43 identificadores con su nombre para mostrar:

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

  Forma elegida para el cambio más chico (no decisión del usuario): `numbers` se conserva y se suma `entries`. Solo `functions/` y sus tests (152 en total). **La app ya lo implementa** (selector obligatorio, `findMatches` por lotería, lectura de `entries`: ver la siguiente pieza). **Deploys de la función (dato del usuario; la salida del CLI no está en el repo)**: la copia de `jornadas` y los alias (`doramaña`, `doradotarde`, `doradonoche`, `pija0`, `pijao`, `pijo`) se desplegaron entre el 2026-10-03 y la madrugada del 2026-10-04; respaldo: la colección ya existía y el log de la función del 2026-10-04 11:03 UTC ya traía `[JORNADAS] resumen`. **HECHO (historial de git)**: esos cambios son posteriores al primer deploy (2026-10-03, hacia las 00:39 de Bogotá, según su log): la copia de `jornadas` (`6067f2c`) es de las 13:12 y el alias (`64b5700`) de las 18:01 de ese día. La pieza b3 (`entries`, `64a96ac`, 2026-10-05 21:14) también se desplegó entre el 2026-10-05 y el 2026-10-06, deducido de la conversación, sin confirmar; su primer intento falló en un paso previo (`Error generating the service identity for pubsub.googleapis.com`) sin subir nada, y el segundo terminó en `Successful update operation`. **Que `winning_numbers/{fecha}` ya traiga `entries` NO está verificado**: PENDIENTE (forzar una corrida desde Cloud Scheduler y abrir un documento de hoy). Corrida programada cada hora; el resumen se registra como `[GANADORES] resumen` y `[JORNADAS] resumen`. **La app (hosting) NO está desplegada.** Pendientes: ver "Pendientes consolidados" en `.claude/skills/image-review-workflow.md` y el resumen en `CLAUDE.md`. Detalle en `.claude/skills/image-review-firebase-integration.md` ("Pieza b3").
- **Pendiente (no decidido)**: hasta las 13:30 de su fecha, el documento de la API trae datos de otra jornada (`winning_numbers` de ese día puede mostrar números de otro día; el usuario dijo que los ganadores se revisan al día siguiente) y qué hacer con `discarded` (hoy solo se registra en el log): ver "Pendientes consolidados" en `image-review-workflow`. Detalle en `.claude/skills/image-review-firebase-integration.md` ("Función puente de ganadores (pieza b)").

**Réplica de jornadas (horarios dinámicos, pieza 1) — HECHA y DESPLEGADA (entre el 2026-10-03 y la madrugada del 2026-10-04, dato del usuario; respaldo: la colección ya existía y el log de la función del 2026-10-04 11:03 UTC ya traía `[JORNADAS] resumen`)**: `syncWinningNumbers`, con la copia de `jornadas`, se desplegó en ese lapso; la colección `jornadas` existe en nuestro proyecto con los 5 documentos y el log de cada corrida trae `[JORNADAS]` con el resumen. **Decidido por el usuario (2026-10-03)**: el mismo disparador programado de `syncWinningNumbers`, después de los ganadores y con la misma conexión al ERP y el mismo secreto (sin otro export, secreto ni schedule), copia la colección `jornadas` de `whats-apuestas` a una colección `jornadas` de este proyecto (nombre **PROVISIONAL**, una sola constante): réplica exacta, mismos ids (`festivos`, `manana`, `tarde_1`, `tarde_2`, `noche`) y los 7 campos tal cual, sin convertir nada, sin historial ni fechas de vigencia. Por documento: escribe solo si es distinto o no existe, con `set` completo; antes valida solo que `startTime` y `endTime` sean texto `yyyy-MM-ddTHH:mm:ss.000` con hora y minuto válidos (un documento inválido se omite y se registra con su id y el motivo, sin tocar el guardado); cero documentos del ERP no escriben ni borran nada; nunca se borra nada. Un fallo en un documento no frena a los demás; ganadores y jornadas van en try/catch separados y ninguno lanza al otro. Resumen por documento: `escrito`, `sin-cambios`, `omitido-invalido` o `error` (log `[JORNADAS]`).
- Código: `functions/jornadasSync.js` (`syncJornadas`, `jornadasFirestoreSources`; sin `firebase-admin`, dependencias por parámetro), llamado desde `runWinningNumbersSync` (que ahora también atrapa un fallo de los ganadores y lo registra en vez de rechazar la promesa); en `index.js` solo el import y el `connect`, que devuelve también `jornadas`. Copia el `data()` completo de cada documento (hoy los 7 campos). Tests en `functions/test/jornadasSync.test.js`.
- **Decidido**: "Mañana" vale para las mañanas de todos los días excepto domingos y festivos, que usan `festivos`. La lista de festivos en Firebase queda como pieza aparte.
- **Conversión de ids del ERP a claves de la app** (enum `Shift`): `manana` → `morning`, `tarde_1` → `afternoon1`, `tarde_2` → `afternoon2`, `noche` → `night1`, `festivos` → `holiday`. La réplica guarda los ids del ERP; la conversión no la hace la función.
- **SUPOSICIÓN**: los horarios que se usan son siempre `startTime` y `endTime`.
- **Pieza 3 (el bot la lee) — HECHA (dato del usuario, otro repo, 2026-10-04)**: ver la sección 7.3. **Pendiente (no decidido)**: qué significan `pendingApproval` y `proposed*` en el ERP (la regla de `jornadas` ya está PUBLICADA, confirmado el 2026-10-04). (La pieza 2, la app lee la colección, y la lista de festivos ya están hechas: ver sección 7.3 y `festivos_colombia` arriba.) Detalle en `.claude/skills/image-review-firebase-integration.md` ("Réplica de jornadas").

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
| `/summary` | `SummaryPage` | Requiere sesión iniciada **y** (`isAdmin == true` **o** `isSuperAdmin == true`) (`canViewSummary`, decidido: Revisor y Sumador no la abren); si no, redirige a `/home`. La entrada "Resumen" del menú de `ChatList` solo la ven esas cuentas. Lee datos REALES (ver sección 7.6). Pendiente: los claims se leen solo al iniciar sesión, así que a un admin al que le quiten el rol puede seguir viendo la pantalla hasta que se renueve el token. |
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

**Jornadas laborales** (`lib/core/time/shifts.dart`, enum `Shift`). Cada mensaje se clasifica en una jornada según su hora local al mapearse a dominio (`toDomain`); se trunca al minuto y el fin de cada rango es inclusivo. **Una sola tabla** (paso 7, pieza e), para todas las fechas y todos los mensajes: el horario de la colección `jornadas` del proyecto `whats-apuestas` (DECIDIDO el 2026-09-30). Desde la pieza 2 de horarios dinámicos (abajo) la app la lee de Firestore y la tabla fija es el respaldo. Valores de la tabla fija:
- Mañana (05:30–10:51), tarde 1 (10:58–13:55), tarde 2 (14:01–15:20), noche 1 (15:28–22:15), domingo/festivo (06:00–19:15, domingos y, cargados, los festivos), fuera de jornada.
- Los huecos entre jornadas (10:52–10:57, 13:56–14:00, 15:21–15:27) cuentan como fuera de jornada para reportes, pero en el visor se etiquetan "Fuera de jornada Mañana/Tarde 1/Tarde 2" y se agrupan junto a su jornada. Antes de 05:30, después de 22:15 y el domingo fuera de horario: "Fuera de las jornadas".
- **Se retiraron** la tabla vieja (06:00–10:54, …, noche 2 22:25–22:30) y el corte (`newShiftsEffectiveFromMs`). **Noche 2** (`night2`) ya no existe como jornada: solo queda como valor del enum (la usan `reviewShifts`, etiquetas guardadas y contadores viejos): `getCurrentShift` nunca la devuelve, el diálogo de horarios no la ofrece y el panel de control no tiene su fila. **Sigue** en `ASSIGNABLE_SHIFTS` (`functions/index.js`) y en la regla `shiftKeyValido` (`firestore.rules.draft`): PENDIENTE de limpiar.
- **Etiquetas**: `shiftNames` tiene las etiquetas ACTUALES; las viejas están en `legacyShiftNames` y solo sirven para reconocer registros y documentos ya guardados (`shiftFromLabel`) y como respaldo de la etiqueta de noche 2. Las claves del enum no cambian.
- **Bot (otro repo) — dato del usuario (2026-10-04; no se puede comprobar desde este repo)**: el worker se reconstruyó en el servidor con la tabla nueva (sin noche 2) y la lectura de `jornadas` y `festivos_colombia`, y arrancó con `Shift config loader iniciado` y la tabla actualizada; siguen llegando imágenes; los 17 tests del repo del bot dieron verde en un contenedor Node 20 el 2026-10-03. **Pendiente** (no decidido; lista única en `.claude/skills/image-review-workflow.md`): retirar noche 2 de `ASSIGNABLE_SHIFTS` (`functions/index.js`) y de la regla `shiftKeyValido`; los contadores `night2` viejos de `shift_image_counters` no se migran y el día del deploy una jornada pudo mezclar límites viejos y nuevos (aceptado); la caché de la PWA sale con el deploy del hosting (`CACHE_NAME` = `whatsapp-monitor-v5`). Los mensajes ya guardados se reclasifican con la tabla única. Detalle en `.claude/skills/image-review-domain.md` ("Jornadas: una sola tabla").
- **Horarios dinámicos**: la pieza 1 (la función programada copia `jornadas` del ERP a una colección `jornadas` de este proyecto, ver sección 5) está hecha y desplegada (entre el 2026-10-03 y la madrugada del 2026-10-04, dato del usuario).
- **Horarios dinámicos, pieza 2 — DECIDIDO por el usuario e IMPLEMENTADO (hosting sin desplegar)**: la app lee `jornadas` y `festivos_colombia` y clasifica con ellos; **la tabla fija actual es el respaldo**. `shifts.dart` guarda una sola tabla activa (`ShiftTable`: rangos de día normal, rango de `holiday` y fechas festivas), inicializada con `fixedShiftTable`; `replaceShiftTable` la reemplaza y `restoreFixedShiftTable` (solo tests) vuelve a la fija; `shiftLastMinute` sale de los rangos. `isHolidayOrSunday` hace que un festivo entre semana se comporte exactamente como un domingo (en `getCurrentShift`, `shiftGapBefore`/`shiftViewerLabel` y `_shiftsOfDay` de Coincidencias). Las etiquetas siguen siendo texto fijo y la zona horaria no cambia. Datasource (`lib/features/shift_schedule/data/`): un `.get()` de cada colección, `Either`, nunca lanza; parte de la tabla fija, convierte ids (`manana`→`morning`, `tarde_1`→`afternoon1`, `tarde_2`→`afternoon2`, `noche`→`night1`, `festivos`→`holiday`), toma hora y minuto de `startTime`/`endTime`, ignora `pendingApproval`/`proposed*`, ignora documentos con horario inválido o inicio posterior al fin (conservan el rango fijo), ids desconocidos y fechas de festivo inválidas. Cargador `shiftScheduleLoaderProvider` (observa `reviewerUidProvider`, disparado con `ref.listen` en `app.dart`): una lectura por sesión, sin reintentos ni timeout, nada lo espera; falla → `[JORNADAS] falló (...)` y queda la tabla que había; tabla distinta → la reemplaza e invalida `shiftStatsProvider`.
  - **Limitaciones aceptadas por el usuario**: los mensajes ya cargados mantienen su etiqueta hasta cambiar de chat o de filtro (solo se recalculan los conteos del panel de control); lo guardado antes del deploy puede quedar con etiquetas desfasadas.
  - **Pendiente (no decidido)**: (las reglas de `jornadas` y `festivos_colombia` ya están PUBLICADAS, confirmado por el usuario el 2026-10-04; el bot ya lee las colecciones, ver arriba) el texto de las etiquetas lleva las horas escritas y no se actualiza si el ERP cambia un horario (defecto cosmético); la zona horaria del dispositivo (un festivo depende de la fecha local: fuera de UTC-5 se podría ver otro día); qué hacer si el ERP trae `pendingApproval: true` o valores en `proposed*` (hoy se ignoran); desplegar el hosting (esperando el visto bueno del cliente).

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

- **Formulario de captura**: vive dentro de `ImageDetailPage` (visor de imágenes de la sección 7.3), como panel lateral exclusivo de pantallas anchas (`AppBreakpoints.reviewForm`), con rol activo asignado, y con esa imagen puntual cubierta por el `reviewShifts` de ese rol (tercera condición; no es un filtrado de qué chats se ven — `allowedGroups` no cambia). Bloquea la navegación entre imágenes hasta guardar el registro de la actual. Arriba, un solo campo **Código** (uno por foto, obligatorio para los dos roles); cada tarjeta de comprobante tiene números (solo Revisor), total y **"Lotería"** (selector obligatorio de una lista cerrada de 43, para los dos roles; el borrador y el registro guardan el identificador y se muestra el nombre; ya no es texto libre ni está desligada de los ganadores: compara contra los ganadores de su misma lotería; no entra en la reconciliación de totales). Un registro guardado antes del código por imagen se ve "Sin código", abre "Editar" con el código vacío y no se sube hasta volver a guardarlo (esquema local sigue en v1). **Pendiente**: validar `codigo` y `loteria` en las reglas (hoy no se validan). **La app — HECHA (2026-10-05, hosting sin desplegar)**: **decidido por el usuario e implementado**: cada comprobante lleva su lotería, elegida de una lista cerrada de 43 identificadores (`lib/core/lotteries/lotteries.dart`, una constante en un solo archivo, con `loteriaDisplayName(id)`, que devuelve el nombre o el mismo texto si no está en la lista) y obligatoria para los dos roles; `Comprobante.loteria` guarda el identificador y sigue siendo `String?` (un registro viejo trae texto libre o null); un ganador solo coincide con un número de la misma lotería; la app lee `entries` de `winning_numbers/{fecha}` y dejó de leer `numbers`. Detalle y lista en `.claude/skills/image-review-firebase-integration.md` ("Lotería por comprobante y comparación por lotería (la app)"). `flutter test`: 938 en verde (antes 906); solo fallan los 2 conocidos de `package:web`. **Pendientes (no decididos)**: ver "Pendientes consolidados" en `.claude/skills/image-review-workflow.md` (hosting con el visto bueno del cliente, función antes que hosting; boletos viejos de texto libre y ganadores de una lotería fuera de la lista no coinciden con nada; si el Revisor necesita una lotería que no está en la lista, hoy no puede guardar). (El aviso para los registros viejos que no se pueden subir se descartó por decisión del usuario: son datos de prueba.)
- **Persistencia local**: con `hive_ce`, separada por usuario y por rol; sobrevive a recargar la app.
- **Subida**: un indicador por jornada con registros pendientes, subida manual por lote — **REAL a Firestore** (`FirestoreReviewUploader`; el uploader se construye solo al confirmar "Subir"). Las reglas se publicaron el 2026-10-01 y la primera escritura real funcionó (antes se rechazaba con `permission-denied` y los registros quedaban pendientes). Cada fallo deja un `debugPrint` con el messageId y el tipo de error. `SimulatedReviewUploader` se borró (HECHO).
- **Rol activo**: `currentReviewRoleProvider` lee el custom claim `reviewRole` de `AuthenticatedUser` (sesión autenticada) como fuente real; `--dart-define=REVIEW_ROLE=revisor|sumador` queda solo como fallback de desarrollo para cuando no hay sesión real (ver sección 5).
- **Asignación de grupo + jornada**: `setReviewRole` (claim `reviewRole`) y `updateReviewShifts` (lista `reviewShifts` en Firestore, con validación de unicidad por rol+grupo+jornada) y su UI en `AdminPage` (sección 7.4) ya existen, están probadas y desplegadas a producción. `reviewShiftsProvider` lee esa lista (una vez, sin `.snapshots()`) y condiciona el formulario de captura de arriba.

### 7.6 Resumen (`lib/features/summary/`)

**Qué hace:** pantalla de reconciliación por jornada y grupo (compara lo registrado por Revisor y Sumador), en la ruta `/summary` (ver sección 6).

**Estado real: la pantalla lee datos REALES** (paso 7, pieza d): `summaryRepositoryProvider` devuelve `realSummaryRepositoryProvider` — registros de `image_reviews` (consulta de grupo de colecciones), contadores de `shift_image_counts` y nombres de `group_stats` —, solo para admin y superAdmin, con la caché de 5 minutos. **HECHO (verificado por el usuario el 2026-10-02)**: funciona con una cuenta admin; leyó los registros, los contadores y los nombres. `MockSummaryRepository` (escenarios inventados y deterministas por fecha) se borró (HECHO). Un error se ve en pantalla con el texto completo del `Failure` y "Reintentar"; además deja un `debugPrint` `[RESUMEN] falló (...)` (los errores de Firestore y de permisos con su texto completo, que si falta un índice trae el enlace para crearlo; los demás solo con el tipo). Coincidencias (7.7) también lee datos reales. Ver `.claude/skills/image-review-domain.md` para las reglas de reconciliación.

**Capa de datos real, conectada** (paso 7, pieza d, capa 1; nombres provisionales): `FirestoreSummaryRepository` y tres datasources en `features/summary/data/` — registros del día de todos los grupos (consulta de grupo de colecciones sobre `registros` por `fechaJornada`), contadores del bot del día (`shift_image_counts` por `shiftDate`) y nombre de cada grupo (`group_stats/{chatJid}`). Probada con datasources falsos; sus providers están en `real_summary_providers.dart`. Cómo agrega cada rol: `image-review-domain` § "Cómo se arma el Resumen real". El índice de grupo de colecciones sobre `fechaJornada` ya existe (2026-10-02). **Pendiente, no decidido**: `lastIndex` puede ser mayor que las imágenes reales; el costo en lecturas por consulta (hasta unas 3600; la caché de 5 minutos evita repetirla).

**Caché del Resumen (activa, sobre el repositorio real)**: `SummaryCache` en memoria, por fecha: TTL de 5 minutos, solo resultados correctos (un error nunca se guarda), una sola lectura por fecha a la vez y máximo 10 fechas. Botón "Actualizar" en la barra superior (y "Reintentar" tras un error): invalida la fecha elegida y vuelve a la fuente. Los nombres de grupo se guardan toda la sesión, solo los encontrados (`CachedGroupNameDatasource`, aplicado en `real_summary_providers.dart`). **Pendiente**: la caché no se comparte entre pestañas ni sesiones; un registro subido después puede tardar hasta 5 minutos en aparecer (el botón lo evita);  `lastIndex` puede ser mayor que las imágenes reales.

**Aviso de imágenes sin registrar:** bajo cada rol de una jornada ya terminada, una línea informativa ("Faltan N imágenes por registrar") compara `imagenesEnJornada` (formato real de `shift_image_counts`) contra lo que registró ese rol. Es solo informativa y no altera el estado de dinero (cuadra/descuadre/pendiente).

El reloj del Resumen (`clockProvider`) se lee una vez por construcción de la lista: una jornada que termina con la pantalla abierta no muestra el aviso hasta que se reconstruya (por ejemplo, al cambiar la fecha).

### 7.7 Coincidencias (`lib/features/matches/`)

**Qué hace:** pantalla dedicada que cruza los números ganadores contra lo que registró el Revisor, organizados por fecha (selector de calendario, hoy por defecto) y jornada (nunca combinadas en un total del día), en la ruta `/matches` (ver sección 6). Acceso solo para `isAdmin`/`isSuperAdmin` (`canViewMatches`), independiente de `reviewRole`/`reviewShifts` y sin filtro por `allowedGroups`; se abre desde el ítem "Coincidencias" del menú de `ChatList`.

**Estado real: lee datos REALES** (paso 7, pieza c): `matchesRepositoryProvider` devuelve `realMatchesRepositoryProvider` (`FirestoreMatchesRepository`). Los ganadores de una fecha (`winning_numbers/{fecha}`, campo `entries` —pares lotería + número—, desde el 2026-10-05; nombre y forma **PROVISIONALES**) se comparan contra los números del **Revisor** de TODAS las jornadas y grupos de esa fecha (consulta de grupo de colecciones sobre `registros` por `fechaJornada` y `rol`); cuenta la lotería y el número (un ganador solo coincide con un número de la misma lotería; desde el 2026-10-05; la app (hosting) sigue sin desplegar y la función que escribe `entries` se desplegó entre el 2026-10-05 y el 2026-10-06, deducido de la conversación, sin confirmar). Cada coincidencia lee su mensaje (`whatsapp_messages`: quién lo envió y la hora) y el nombre de su grupo (`group_stats`, con la caché del Resumen; si no existe, el `chatJid`). Un error se ve en pantalla con "Reintentar" y deja un `debugPrint` `[COINCIDENCIAS] falló (...)` (misma política que el Resumen, `failureLogLine`). **HECHO (verificado por el usuario el 2026-10-02)**: la regla de lectura de `winning_numbers` está publicada y la pantalla abrió sin error con una cuenta admin, mostrando "Todavía no hay ganadores". La colección `winning_numbers` existe desde el 2026-10-03: la escribe cada hora la función puente desplegada (ver sección 5 y `.claude/skills/image-review-firebase-integration.md`). `MockMatchesRepository` se borró (HECHO). **Pendiente**: el índice de grupo de colecciones sobre `fechaJornada` y `rol` (el enlace sale del error de la primera consulta con ganadores); caché; costo en lecturas; probar "Ver imagen" con una imagen real.

**Piezas clave:**
- `FirestoreMatchesRepository` (`data/repositories/`) y sus datasources (`data/datasources/`: registros del Revisor, ganadores del día y mensaje por id), cableados en `real_matches_providers.dart`; `MockMatchesRepository` se borró.
- `findMatches` (`domain/helpers/`) — recibe los ganadores como pares (lotería, número) y solo compara dentro de la misma lotería (un registro con la lotería nula, vacía o fuera de la lista no coincide con nada); regla de 2, 3 y 4 cifras, **decidida por el usuario (aclaración del cliente) e implementada**: tras `trim` en ambos lados, sin normalizar ni quitar ceros a la izquierda y sin validar que sean cifras; con un ganador de 4, un número de 4 coincide si es igual al ganador completo, uno de 3 si es igual a sus últimas 3 y uno de 2 si es igual a sus últimas 2; con un ganador de 3, un número de 3 coincide si es igual al ganador completo y uno de 2 si es igual a sus últimas 2; un número de 4 nunca coincide con un ganador de 3; números de otra longitud (1, 5 o más) y ganadores de longitud distinta de 3 o 4 se ignoran sin aviso. La función puente no cambia: los ganadores siguen siendo de 3 o 4 cifras. Devuelve una entrada por registro coincidente, no por ganador, y nunca dos veces (la entrada no lleva el ganador).
- `canViewMatches` (`domain/helpers/`) — `isAdmin || isSuperAdmin`; la usan tanto el guard de `router.dart` (vía `lib/app/auth_redirect.dart`) como el ítem del menú, para que nunca diverjan.
- `matchesDateProvider`/`matchesRepositoryProvider`/`dayMatchesProvider` (`presentation/providers/`) — fecha activa, instancia del repositorio y las coincidencias del día elegido.
- `MatchesPage` (`presentation/pages/`) — estados carga/vacío/error, selector de fecha, siempre una `JornadaMatchesSection` por jornada (una jornada sin coincidencias dice "Todavía no hay ganadores"; el vacío de página solo aparece si el día no tiene jornadas).
- `MatchDetailDialog` (`presentation/widgets/`) — detalle de una coincidencia ("Ver más"), sin "Mensaje editado"; la imagen se pide bajo demanda al tocar "Ver imagen" (`realImageEnabled`, `true` por defecto; no se probó todavía con una imagen real).

**Limitaciones conocidas:**
- El repositorio real arma las jornadas del día (domingo o festivo cargado: solo `holiday`, con `isHolidayOrSunday`).
- `MatchesPage` y `MatchDetailDialog` tienen dos ramas de `ResponsiveLayout` casi idénticas (igual que `SummaryPage`, sección 7.6); la diferencia real móvil/escritorio está solo en `_MatchTile` (dentro de `JornadaMatchesSection`) y su skeleton. Unificar esas ramas casi idénticas es un refactor pendiente, no hecho.
- `DayMatches.tieneGanador` significa "hubo coincidencia", no "hubo número ganador" — el vacío de página de `MatchesPage` usa `jornadas.isEmpty`, no ese getter.
- El texto "Editado" del visor (mensaje de WhatsApp editado, barra superior de `ImageDetailPage` — ver sección 7.3) y el chip de estado del registro de revisión (`ReviewStatusChip`, cuando el registro se re-guardó) coexisten con el mismo texto y color. Esta pantalla ya no muestra nada de "editado" (se quitó `messageEdited`).
- La altura del skeleton (`MatchesSkeleton`) se calibró con datos cortos (tolerancia de 12 px sobre una forma representativa); con un nombre de grupo de ~40 caracteres o un chatJid real, la sección en móvil puede salir algo más alta que esa aproximación.
- **Pruebas manuales pendientes**: un día con ganadores (cuando exista `winning_numbers`), un domingo, "Ver imagen" con una imagen real, y anchos de 360, ~750 y 1280 px.

---

## 8. Convenciones importantes para nuevas features

- **Nunca lanzar excepciones desde `data`/`domain`** — siempre `Either<Failure, T>`.
- **Nunca setear custom claims (`admin`/`superAdmin`) desde el cliente** — todo pasa por Cloud Functions.
- **Nunca reemplazar el objeto completo de custom claims de un usuario** (`admin.auth().setCustomUserClaims`) **sin leer antes los claims existentes** con `getUser()` y fusionar — hacerlo sin merge borra silenciosamente cualquier otro claim que el usuario tuviera (bug real, corregido en `functions/index.js`, `setUserRole`; el mismo patrón se repite en `setReviewRole` y, desde el arreglo de `functions/set-admin.js`, también en ese script).
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

**Estado de despliegue (revisión del 2026-10-06)**. HECHO = verificado por el repo; DATO DEL USUARIO = no se puede comprobar desde el repo.
- Función `syncWinningNumbers` (`whatsapp-pro-3d483`): DESPLEGADA (dato del usuario): la copia de `jornadas` y los alias entre el 2026-10-03 y la madrugada del 2026-10-04 (respaldo: la colección ya existía y el log del 2026-10-04 11:03 UTC ya traía `[JORNADAS] resumen`; el historial de git confirma que esos commits son posteriores al primer deploy); la pieza b3 (`entries`), entre el 2026-10-05 y el 2026-10-06, deducido de la conversación, sin confirmar. **No verificado**: que `winning_numbers/{fecha}` ya traiga `entries`.
- Bot (otro repo): reconstruido en el servidor con la tabla nueva (sin `night2`) y la lectura de `jornadas` y `festivos_colombia`, arrancó con `Shift config loader iniciado` y la tabla actualizada, 2026-10-04; siguen llegando imágenes; los 17 tests del repo del bot dieron verde en un contenedor Node 20 el 2026-10-03 (dato del usuario).
- Hosting de la app: **NO desplegado**, esperando el visto bueno del cliente. Saldrá con ese deploy, ya commiteado: la caché de la PWA (`CACHE_NAME` = `whatsapp-monitor-v5`, verificado en `web/sw.js`), la clasificación con horarios y festivos desde Firestore (con la tabla fija de respaldo), la regla de comparación de 2, 3 y 4 cifras y la lotería obligatoria por comprobante comparada por lotería leyendo `entries`. **Orden obligatorio: la función antes que el hosting**, porque la app nueva lee solo `entries`.
- Reglas de Firestore: las de `jornadas` y `festivos_colombia` se publicaron el 2026-10-04; no hay reglas nuevas para esta entrega.
- Colecciones: `jornadas` (5 documentos, copiada del ERP cada hora), `festivos_colombia` (10 documentos, 2026 a 2035, campo `fechas`, cargada el 2026-10-03) y `winning_numbers` (campos `numbers` y `entries`). Los documentos de prueba de `image_reviews` se borraron el 2026-10-04.
- Fuera de los repos: `~/BOT_DOCUMENTATION.md` (servidor) y `~/check_shift_counts.js` siguen describiendo la tabla vieja con `night2` (PENDIENTE de actualizar; no se tocaron).
- Los pendientes sin decidir están en una sola lista: `.claude/skills/image-review-workflow.md` ("Pendientes consolidados"), resumida en `CLAUDE.md`.

- `flutter test` falla en `message_bubble_test.dart` y `message_list_test.dart` por un problema de compatibilidad de `package:web` con el runner de tests en la VM de Dart (no afecta `flutter build web`, que compila limpio — confirmado). Causa: `message_bubble.dart` importa `package:web/web.dart` sin condicionar por plataforma, y esa librería solo funciona en targets web reales (dart2js/dartdevc/wasm), no en la VM. Si algún día se compila esta app para Android/iOS/Windows/macOS/Linux (las carpetas de esas plataformas existen en el repo), ese mismo import probablemente rompería la compilación ahí — pendiente de envolver con un import condicional o `kIsWeb`.
- Swipe-hacia-abajo-para-cerrar en el visor de imágenes: no implementado (ver sección 7.3).
- No hay `firestore.rules` ni `storage.rules` desplegables en el repo; `firestore.rules.draft` es solo la copia de lo publicado a mano en la consola (2026-10-01), sin referenciar en `firebase.json` (ver sección 5).
- No hay emuladores de Firebase para la app ni para las funciones: ni bloque `emulators` en el `firebase.json` de la raíz, ni cableado en Flutter para apuntar a un emulador local (solo `firestore-rules-test/` tiene su propio `firebase.json` con un emulador local de Firestore, para probar `firestore.rules.draft`). Probar Cloud Functions hoy significa mocks del Admin SDK (`functions/test/`) o pruebas cuidadosas contra producción con cuentas de prueba.
- Versión de `firebase-functions` en producción — **SUPOSICIÓN**, no verificada: probablemente 7.4.0. El deploy del 2026-09-27 (`setReviewRole`/`updateReviewShifts`) salió de un árbol que ya tenía 7.4.0 en `functions/package.json` y en el lock (`a013a33`, anterior a `0f8d2c0`; `git log` no muestra cambios de `package.json` ni del lock desde entonces), y los de `syncWinningNumbers` (2026-10-03 y despliegues posteriores, ver la sección 10) del mismo `package.json` (`git log` no muestra cambios de `package.json` ni del lock desde `a013a33`). El CLI no imprime la versión desplegada, así que no se da por hecho (antes este punto decía que producción tenía 7.2.5 y que 7.4.0 no se había desplegado).
- La lista `reviewShifts` guarda la jornada por el identificador del enum Dart (p. ej. `afternoon1`), mientras los registros del feature de revisión de imágenes guardan la etiqueta en español (p. ej. "Jornada Tarde 1 (10:55 – 13:58)") — hará falta un mapeo entre ambos al implementar el filtrado por asignación (ver `.claude/skills/image-review-roles.md`).
- `updateReviewShifts` valida la unicidad de (rol, grupo, jornada) leyendo `listUsers(1000)` + `getAll` batcheado de Firestore, sin transacción entre el chequeo y la escritura — riesgo aceptado para una acción manual y poco frecuente (dos superAdmins asignando al mismo tiempo podrían duplicar la tupla), no resuelto con infraestructura nueva.
- `pubspec.yaml` declara `cached_network_image` y `json_serializable` como dependencias, pero no se encontró ningún uso de ninguna de las dos en `lib/` (ni `CachedNetworkImage`, ni `@JsonSerializable`/archivos `.g.dart` generados) — posibles dependencias sin usar, a confirmar antes de quitarlas.
