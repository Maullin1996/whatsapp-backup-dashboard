---
name: image-review-offline-sync
description: >
  Estrategia offline-first para los formularios de Revisor/Sumador del
  feature de revisión de imágenes de whatsapp_monitor_viewer: los
  formularios se llenan y guardan en local (la PWA ya cachea imágenes),
  nunca se sincronizan automáticamente mientras se diligencian, y la
  subida a Firebase se dispara **por jornada**, de forma manual, con un
  indicador/botón que vive en el listado de mensajes del chat (arriba
  del botón flotante de ir al último mensaje) — visible en cuanto hay
  al menos un registro pendiente, sin depender de contar imágenes para
  saber si la jornada "ya terminó" (esa idea se descartó, ver
  `image-review-domain` § Cierre de jornada). **La conexión real a
  Firestore/Cloud Functions no se activa hasta que el usuario lo
  autorice explícitamente — hasta entonces, toda "subida" se simula
  imprimiendo en consola.** Consulta esta skill SIEMPRE que se trabaje
  en: cualquier mecanismo de guardado local de un registro de
  Revisor/Sumador, el botón/flujo de subida por jornada, el manejo de
  conflictos o reintentos al sincronizar con Firestore, o cualquier
  decisión de qué vive en local vs. qué vive en el servidor para este
  feature — aunque el usuario no diga "offline" ni "cache"
  explícitamente. Requiere haber leído primero `image-review-domain`
  (qué es un registro, y por qué se descartó `shiftImageIndex` como
  señal de cierre) e `image-review-roles` (quién lo llena y cuándo, y
  la asignación de grupo+jornada por persona).
---

# Offline-first: formularios de Revisor/Sumador

Esta skill cubre **dónde vive el dato antes de llegar a Firebase**, no
qué contiene el formulario (`image-review-domain`) ni quién puede
llenarlo (`image-review-roles`).

## Contexto: por qué offline-first

La app ya es una PWA y muchas imágenes quedan cacheadas en el
navegador/dispositivo. La idea es aprovechar eso: Revisor y Sumador
deben poder **seguir trabajando aunque la conexión sea mala o
intermitente**, sin que cada campo que escriben dispare una llamada a
Firestore. Lo único que sí requiere conexión es el momento explícito de
subir todo lo acumulado.

## ⚠️ Regla de trabajo del usuario: NO conectar a Firebase real sin autorización explícita

Aunque esta skill describe el diseño final con subida real a Firestore,
**el usuario decide cuándo se activa esa conexión de verdad**. Mientras
no dé esa autorización explícita en la conversación:

- La "subida por jornada" (regla 2) se implementa **simulada**: en vez
  de escribir en Firestore, **imprime en consola** (o loguea de forma
  clara) exactamente los datos que se subirían — como si fuera un
  `print`/`debugPrint` del payload — para poder probar el flujo
  completo (guardado local → detectar pendientes → "subir" → limpiar
  el pendiente) sin tocar la base de datos real.
- Esto aplica también a la Cloud Function puente y a cualquier otra
  escritura a Firestore de este feature (`image-review-firebase-integration`).
- No asumas que "ya se puede conectar" porque el resto del feature
  esté probado — la señal de arrancar esa conexión real la da el
  usuario explícitamente, no una sesión de Claude Code por su cuenta.

## Regla central: guardar local, subir manual

1. **Mientras se llena un formulario, todo se guarda solo en local.**
   No hay sincronización automática por campo, por imagen completada,
   ni por temporizador — cero llamadas a Firestore mientras el Revisor
   o Sumador está trabajando.
2. **La subida a Firebase es por jornada, no un botón único "subir
   todo"**: el indicador/botón vive **dentro del listado de mensajes
   del chat, arriba del botón flotante "ir al último mensaje"
   (`GoToLatestMessageButton`)** — no en `ChatHeader` ni en
   `ChatDrawer`. **No depende de detectar "jornada completa" contando
   imágenes** (esa idea se descartó, ver `image-review-domain` §
   Cierre de jornada, porque `shiftImageIndex` puede seguir creciendo
   mientras el Revisor/Sumador todavía está trabajando). En su lugar:
   el indicador aparece **en cuanto existe al menos un registro local
   pendiente** en esa jornada, y la persona asignada a esa jornada+
   grupo (`image-review-roles`) decide cuándo presionarlo — es la única
   con esa asignación, así que es quien sabe si ya dejaron de llegar
   imágenes. Al presionarlo, **se suben solo los registros locales de
   esa jornada específica**, no los de las demás (pueden existir varios
   indicadores a la vez, uno por jornada con pendientes). La validación
   real de que todo quedó bien no es este botón — es la reconciliación
   agregada de sumas (`image-review-domain`, regla 3), que corre del
   lado del servidor/resumen después de subir.
3. **El guardado local debe sobrevivir cerrar/recargar la app**, con un
   mecanismo tipo **SQLite (`sqflite`/`drift`) o `Hive`** (**decidido:
   `hive_ce`**, ver "Decisión de almacenamiento" más abajo) — el usuario
   confirmó que cualquiera de las dos está bien, priorizando la más
   óptima para el volumen esperado: **hasta ~200 imágenes por jornada**
   (o sea, hasta ~200 registros locales pendientes en el peor caso,
   antes de subir esa jornada). Esto descarta soluciones pensadas solo
   para unos pocos valores sueltos (`shared_preferences` no alcanza a
   este volumen de forma cómoda).
   **El registro local nunca duplica la imagen en sí** — solo guarda el
   `storagePath` como referencia (igual que ya hace Firestore con los
   mensajes, ver `PROJECT_DOCUMENTATION.md` § Cloud Storage): la imagen
   la sigue sirviendo el cache de `extended_image`/el navegador, el
   registro local es puramente metadata del formulario (números,
   totales, jornada, correo del autor, etc.).
4. **Ningún dato se pierde si la subida falla a medias.** Si al subir
   "todo" algunos registros fallan (ej. se cae la conexión a mitad de
   camino), los que sí subieron se marcan como sincronizados y los que
   fallaron **siguen en local, disponibles para reintentar** — nunca se
   descartan ni se dejan en un estado ambiguo.
5. **Subir una jornada no es una acción de una sola vez para siempre.**
   Si después de subir llegan registros nuevos a esa misma jornada
   (mensajes que llegaron tarde, por ejemplo), la persona puede seguir
   registrando y volver a presionar el indicador — no diseñar el botón
   ni el estado local como "ya se subió, deshabilitado permanentemente".
6. **Los registros son editables — incluso después de subidos a
   Firestore.** Confirmado por el usuario: no es una edición limitada
   a mientras el registro sigue en local. Esto descarta el diseño
   "append-only" en ambas capas: la persistencia local necesita
   soportar **actualizar** un registro ya guardado (no solo crear uno
   nuevo), y el repositorio que sube a Firestore necesita un método de
   **actualización** de un documento ya subido, no solo inserción. Al
   editar un registro ya subido, debe **quedar una nota visible de que
   fue editado** — reusar el patrón que ya existe en el proyecto para
   mensajes de WhatsApp editados (`isEdited` en `Message`, ver
   `PROJECT_DOCUMENTATION.md`): un campo booleano `editado` (o similar)
   en el registro, mostrado en la UI donde corresponda (resumen, o al
   reabrir el formulario). No hace falta un historial completo tipo
   `edit_attempts` a menos que se pida explícitamente — con el flag
   booleano alcanza por ahora.
7. **Navegación para editar: sin atajo, se busca navegando.** El
   usuario confirmó que no hay una lista/acceso directo a "mis
   registros ya diligenciados" — la persona **navega el visor
   normalmente** (como cualquier imagen) hasta encontrar la imagen que
   quiere corregir. Cuando llega a una imagen que **ya tiene un
   registro guardado** (local o subido), la UI debe mostrar un **botón
   "Editar"** en vez de (o junto a) la vista normal — ver
   `image-review-roles` para el detalle de dónde vive ese botón en
   `image_detail_page`.

## Decisión de almacenamiento: `hive_ce` (+ `hive_ce_flutter`)

**Elegido: `hive_ce` 2.20 + `hive_ce_flutter` 2.3** (Hive guarda en
IndexedDB en web y en archivos en nativo). Verificado en pub.dev al
decidir (sep-2026):

| Opción | Por qué no / sí |
|---|---|
| `hive` (original) | Última versión jun-2022, SDK `<3.0.0`: incompatible con Dart 3 |
| `hive_ce` | Fork comunitario activo (IO Design Team), web + wasm-ready, resuelve sin conflictos con nuestro `pubspec`, **sin archivos extra** (no toca `web/sw.js`, `CACHE_NAME` ni `urlsToCache`) → **elegida** |
| `drift` | En web necesita `sqlite3.wasm` + worker + codegen y cambios en el service worker: demasiado para ~200 registros por jornada |
| `sqflite` | No soporta web, y la app es sobre todo PWA |

Riesgos aceptados: (1) es un fork comunitario de un solo publicador — si
se abandona, migrar cuesta poco porque solo `ReviewLocalDatasource` toca
la librería; (2) sin SQL — se filtra con claves bien diseñadas (abajo);
(3) el navegador puede desalojar IndexedDB si no es almacenamiento
persistente (Safari sin instalar la PWA es el caso más agresivo): pedir
`navigator.storage.persist()` queda para un paso aparte, no está hecho.

### ⚠️ Limitación conocida: una sola pestaña por navegador

Hive no coordina escrituras entre pestañas. **Se asume una sola pestaña
de la app por navegador.** Con varias, cada pestaña tiene su propia caché
del box y **no ve lo que guardó la otra hasta recargar**; dos pestañas
guardando la misma imagen pueden pisarse. No hay bloqueo ni aviso hoy.

## Reglas del registro local (implementadas)

1. **Solo se persisten registros GUARDADOS** (botón "Guardar" con el
   formulario válido). Los borradores a medio llenar viven solo en
   memoria: si se recarga la página sin guardar, el borrador se pierde
   (aceptado).
2. **Qué guarda el registro** (`ImageReviewRecord`, ver
   `image-review-domain`): además de la forma del formulario, `rol`,
   `storagePath` (referencia; **nunca** la imagen ni una URL completa),
   `fechaJornada` (`yyyy-MM-dd`, día de la jornada = fecha del mensaje en
   hora local, calculada con `fechaJornadaDe(messageTimestamp)`; **no** es
   `Message.messageDate`, que a pesar del nombre guarda la hora "HH:mm",
   ni `registradoEn`), `registradoPor`, `editado` y `estadoSync`.
3. **`estadoSync` (`EstadoSync { pendiente, sincronizado }`)**: un registro
   nuevo nace `pendiente`. **Re-guardar (editar) un registro, aunque
   estuviera `sincronizado`, lo devuelve a `pendiente` y pone
   `editado = true`** (habrá que volver a subirlo). Lo decide presentation
   (`ReviewDraftNotifier.save`), no el repositorio. **Pasa a `sincronizado`
   solo con la subida por jornada** (`ReviewUploadNotifier`, hoy SIMULADA,
   ver "Indicador de subida por jornada" más abajo).
4. **Separación por usuario, con el `uid`** (`AuthenticatedUser.id`), no el
   email: `reviewerUidProvider`. Todas las claves llevan el uid, así que
   otro usuario en el mismo navegador ve y guarda solo lo suyo. **Cerrar
   sesión NO borra nada del almacenamiento**: los pendientes de ese usuario
   siguen ahí cuando vuelva a entrar. Al cambiar de usuario,
   `imageReviewRepositoryProvider` apunta al almacenamiento del nuevo uid;
   los **borradores en memoria sí se reinician**. Sin sesión el repositorio
   es uno vacío (lecturas vacías, guardar → no autorizado) que no toca los
   datos.
5. **Un registro por imagen y por rol** (clave `(messageId, rol)`), igual
   que antes: guardar un rol nunca toca el otro.
6. **Claves** (un solo `LazyBox<String>`, cada valor es el JSON del
   `ImageReviewRecordModel`; cada componente va con `Uri.encodeComponent`):
   - registro: `r|uid|rol|messageId`
   - índice de pendientes: `p|uid|rol|chatJid|fechaJornada|shift|messageId`
     (valor vacío), que existe **solo mientras el registro está
     pendiente**. `getPending` recorre las claves con ese prefijo, sin
     leer el resto. Registro e índice se escriben juntos (`putAll`) al
     dejarlo pendiente; al pasar a sincronizado primero se escribe el
     registro y luego se quita el índice (un corte a mitad deja un índice
     viejo que se ignora, nunca un pendiente invisible).
7. **Esquema versionado**: cada registro guarda `v` (hoy 1,
   `ImageReviewRecordModel.currentSchemaVersion`); `migrate` es el punto
   donde se encadenan las migraciones futuras. Una versión más nueva que
   la soportada, o un registro ilegible, falla con un `Failure.storage`
   que **identifica el messageId** (en `getByMessageId` y `getPending`);
   no se saltan registros en silencio.
8. **Arquitectura**: `ReviewLocalDatasource` (`data/datasources/`) es lo
   único que toca `hive_ce`, devuelve `Either<Failure, T>` y nunca se llama
   desde un Notifier. Las entidades de domain no llevan anotaciones de la
   librería (el modelo propio de `data/` se encarga de la serialización).
   `LocalImageReviewRepository(datasource, uid)` reemplaza a
   `InMemoryImageReviewRepository` **solo** en
   `imageReviewRepositoryProvider`; el de memoria se mantiene para tests.
9. **Apertura**: `ReviewLocalDatasource.open()` se llama una vez en
   `main.dart` (antes de `runApp`) y se inyecta con un override de
   `reviewLocalStorageProvider`, para que el repositorio siga siendo
   síncrono. Si falla no tumba la app: el repositorio pasa a uno "no
   disponible" (todo `Left(Failure.storage)`) y el panel muestra el error.
   `savedRecordProvider` desactiva el reintento automático de Riverpod 3
   (`retry: null`): un error de almacenamiento no es transitorio y con
   reintentos el panel quedaría "cargando" en vez de mostrarlo.
10. **Consulta de pendientes** (paso 2, solo repositorio, sin UI):
    `getPending(chatJid, fechaJornada, shift, rol)` del usuario actual;
    no devuelve sincronizados; ordenados por `registradoEn`.
11. **Jornadas con pendientes** (`getPendingJornadas(chatJid, rol)`, paso
    4): recorre SOLO las claves del índice `p|uid|rol|chatJid|` (sin leer ni
    deserializar registros) y devuelve `PendingJornada { fechaJornada, shift,
    cantidad }` de cualquier día. No depende de los mensajes cargados ni del
    filtro de fechas: un pendiente de otro día nunca queda invisible.
12. **Limpieza de índices huérfanos en `pending()`** (hallazgo del paso 4):
    como `getPendingJornadas` cuenta por índice, un índice viejo (corte entre
    escribir el registro sincronizado y quitar el índice) inflaría el
    contador y el indicador quedaría fijo. Por eso `pending()` — que solo
    llama `LocalImageReviewRepository.getPending`, el camino del paso 3 —
    borra un índice cuando el registro no existe o ya está sincronizado.
    Solo escribe cuando detecta orfandad (nunca en una lectura normal) y
    RELEE el registro justo antes de borrar (`_deleteIfStale`), para no borrar
    el índice de un registro que se re-guardó como pendiente mientras se leía.
    Queda una ventana mínima entre esa relectura y el `delete` (aceptable con
    una sola pestaña).

## Indicador de subida por jornada (paso 4 — HECHO, subida SIMULADA)

- **Dónde vive**: `PendingUploadIndicators`
  (`image_review/presentation/widgets/pending_upload_indicators.dart`), un
  `Positioned` dentro del `Stack` de `MessageList`, encima del hueco de
  `GoToLatestMessageButton` (`bottom = 20 + 56 + AppSpacing.md`, mismo `right`
  que el botón). `MessageList` no sabe nada del feature: solo inserta el
  widget, que lee `currentReviewRoleProvider` por dentro.
- **Qué muestra**: una píldora por jornada del chat activo con pendientes del
  rol activo. Reposo: "<Rol> · <jornada corta> · N pendientes" (+ ", dd/MM/yyyy"
  solo si el día no es hoy). Jornada corta = `shortShiftName` (las dos
  "Noche" se distinguen por su hora de inicio). Sin pendientes no ocupa
  espacio. No hay condición de rol: hoy el rol activo siempre existe y un
  pendiente solo existe si el usuario guardó algo con ese rol; sin condición
  de ancho (también en móvil).
- **Datos**: `pendingUploadsProvider` (FutureProvider) depende SOLO del chat
  activo, el rol activo y el repositorio (`getPendingJornadas`). Se invalida
  al guardar (`ReviewDraftNotifier.save`) y al terminar una subida.
- **Subida**: tocar la píldora → diálogo "Subir N registros de <jornada>,
  <fecha o 'hoy'>" → `ReviewUploadNotifier.upload(jornada)` (provider
  `reviewUploadProvider`). Sube registro por registro con el
  `ReviewUploader` (domain; hoy `SimulatedReviewUploader` en `data/sync/`,
  que hace `debugPrint` de `image_reviews/<messageId>_<rol>` y el payload
  `toUploadMap()` = `toMap()` sin `v` ni `estadoSync`; nunca falla). Cada
  registro subido se marca `sincronizado` de inmediato; los que fallan siguen
  pendientes. El estado del notifier es el avance por jornada
  (`hechos`, `total`): la píldora muestra "Subiendo X de N" y no se puede tocar
  mientras sube. Al terminar: SnackBar verde ("N registros subidos") o de
  advertencia ("N subidos, M no se pudieron subir; siguen pendientes").
- **Guarda contra ediciones**: antes de marcar sincronizado se relee el
  registro y se compara `registradoEn` (cada guardado lo renueva): si cambió
  durante la subida, no se marca (lo subido ya es una versión vieja) y se
  cuenta como `editados`.
- **Corte al salir del chat**: antes de subir CADA registro se comprueba que
  el notifier siga montado y que el chat activo sea el de la jornada; si no,
  se corta el lote. Lo ya subido queda sincronizado, el resto pendiente
  (`sinIntentar`), listo para reintentar cuando reaparezca el indicador.
- **Si subió pero no se pudo marcar** (falló el guardado local): cuenta como
  fallido y seguirá pendiente; se re-sube (mismo id de documento, no duplica).

### Pendiente de diseño para la integración real (paso 7)

El uploader simulado nunca falla ni se cuelga, así que hoy no hay nada que
proteja contra una conexión mala. Antes de conectar Firestore de verdad hay
que decidir: **verificar la calidad de conexión antes de subir y/o un
timeout por registro** (un registro colgado hoy bloquearía toda la jornada
con "Subiendo X de N" indefinido). Decidirlo junto con la implementación
real de `ReviewUploader`.

## Forma de trabajo dentro de esta skill

Siguiendo la convención del proyecto ("nunca tirar todo de un solo
golpe"), esta parte del feature se implementa por capas, probando cada
una antes de seguir:

1. ✅ **Guardado local de un solo registro** (una imagen, un formulario) —
   hecho: sobrevive a recargar y a cerrar/reabrir la pestaña (probado
   cerrando y reabriendo el almacenamiento en tests).
2. ✅ **Listado de pendientes por jornada** — hecho, solo en el
   repositorio (`getPending`), sin UI (esto ya no requiere "detectar
   si está completa", solo listar lo que hay).
3. ✅ **Subida individual** de un registro pendiente — hecha SIMULADA
   (`ReviewUploader` + `SimulatedReviewUploader`); la real espera autorización.
4. ✅ **Subida por jornada** con éxitos/fallos parciales — hecha (simulada),
   ver "Indicador de subida por jornada".
5. ✅ **UI del indicador/botón por jornada** en el listado de mensajes,
   arriba de `GoToLatestMessageButton` — hecha.

## Zona gris / a confirmar antes de implementar

- **`navigator.storage.persist()`**: pedir almacenamiento persistente al
  navegador (para que no desaloje IndexedDB) no está implementado; va en
  un paso aparte.
- **Varias pestañas**: hoy es una limitación documentada (arriba), sin
  bloqueo ni aviso.
