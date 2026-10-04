---
name: image-review-workflow
description: >
  Orquesta CÓMO se trabaja el feature completo de revisión de imágenes
  (roles Revisor/Sumador, formulario en image_detail_page, guardado
  offline, integración con Firebase) de whatsapp_monitor_viewer: en qué
  orden leer las skills `image-review-domain`, `image-review-roles`,
  `image-review-offline-sync` e `image-review-firebase-integration`, el
  principio de implementar por capas sin tirar todo de un solo golpe, un
  roadmap sugerido de por dónde empezar, y una lista consolidada de
  pendientes que bloquean partes de la implementación. Consulta esta
  skill SIEMPRE que se vaya a **empezar** a trabajar en cualquier parte
  de este feature (aunque el pedido sea puntual, tipo "agrega el botón
  de subir jornada" o "crea el formulario del revisor") para saber qué
  otra skill leer primero y en qué orden hacer las cosas — no reemplaza
  a las otras cuatro skills, las organiza.
---

# Cómo se trabaja el feature de revisión de imágenes

Esta skill **no tiene reglas de negocio propias**. Es el mapa de las
otras cuatro y el proceso para no reinventar ni romper nada en cada
sesión nueva.

## Mapa de skills del feature

| Skill | Cubre | Leer cuando... |
|---|---|---|
| `image-review-domain` | Vocabulario, reglas de negocio, modelo `Message` existente, decisión de cierre de jornada | **Siempre primero**, en cualquier tarea de este feature |
| `image-review-roles` | Revisor/Sumador, custom claims, activación desde `AdminPage`, asignación de grupo+jornada, restricción tablet/PC, validación de navegación | Se toca autenticación/permisos, `AdminPage`, o el guard de `image_detail_page` |
| `image-review-offline-sync` | Guardado local, indicador manual de subida por jornada | Se toca persistencia local, el botón/indicador de subida, o cualquier "¿esto ya se guardó?" |
| `image-review-firebase-integration` | Cloud Function puente, números ganadores, jornadas externas | Se toca la Cloud Function puente, la pantalla de coincidencias, o la fuente de jornadas |

También sigue vigente `ui-design` (la skill de diseño ya existente del
proyecto) para **cualquier pantalla o widget nuevo** de este feature —
no es exclusiva de este feature, aplica igual aquí.

## Principio: nunca todo de un solo golpe

Igual que en los otros proyectos del usuario (`meclab-flutter-dashboard-demo`,
`motor-ble-control`), este feature se construye **una capa a la vez**,
probando cada pieza antes de seguir con la siguiente. Señales de que se
está tirando demasiado de una vez:

- Un solo PR/sesión que toca `AdminPage` + el formulario de
  `image_detail_page` + persistencia local + Cloud Functions al mismo
  tiempo. Son 4 piezas de 4 skills distintas — repartir en sesiones
  separadas.
- Implementar algo marcado como "Zona gris" en cualquiera de las cuatro
  skills sin haberlo confirmado antes con el usuario.
- Escribir código de `image-review-firebase-integration` conectado a
  Firebase real cuando la skill dice explícitamente que **por ahora va
  mockeado**.

## Regla de trabajo explícita: ninguna conexión real a Firebase sin autorización

El usuario decide, en la conversación, cuándo se activa cualquier
escritura real a Firestore/Cloud Functions de este feature (subida por
jornada, Cloud Function puente de números ganadores/jornadas). Hasta
que dé esa autorización explícita, **toda "subida" se implementa
imprimiendo en consola** los datos que se enviarían — así se prueba el
flujo completo sin tocar la base de datos real. Esto aplica en
`image-review-offline-sync` e `image-review-firebase-integration`, y
sigue vigente aunque el resto del feature ya esté probado con mocks:
no es una señal de "ya se puede conectar", solo el usuario la da.

**Actualización (paso 7, capa 6)**: el usuario autorizó y decidió cablear
la subida real por jornada (`reviewUploaderProvider` → `FirestoreReviewUploader`,
sin bandera). La regla sigue vigente para todo lo demás: Cloud Function
puente, publicar reglas, cualquier otra escritura.

## Roadmap sugerido (a confirmar/ajustar con el usuario, no es definitivo)

Basado en dependencias reales entre las piezas — **no lo asumas como
orden final sin confirmarlo cuando se vaya a empezar a implementar**:

1. **Roles + asignación primero** (`image-review-roles`): activar
   `revisor`/`sumador` como custom claims + UI en `AdminPage`, **junto
   con la asignación de grupo+jornada** (esto ya no es opcional/futuro,
   quedó confirmado como parte del mismo paso). Sin esto, no hay quién
   use el formulario que viene después, y es la pieza más aislada del
   resto (no depende de las otras tres).
2. **Formulario de captura** (`image-review-domain` + `image-review-roles`):
   comprobantes/números/total en `image_detail_page`, restringido a
   tablet/PC, con el bloqueo de navegación hasta guardar el registro
   (en ambos sentidos). Empieza
   guardando en memoria (Riverpod) nada más, sin persistencia todavía —
   eso es el siguiente paso.
3. **Persistencia local** (`image-review-offline-sync`) — ✅ hecha con
   `hive_ce` (pasos 1 y 2 de esa skill: guardar y listar pendientes por
   jornada, sin UI): sobrevive a recargar, separada por uid y por rol.
   Mover el guardado del formulario a SQLite/Hive real, probando que sobrevive
   un reload antes de seguir. Como ya no hay que "detectar jornada
   completa" (se descartó, ver `image-review-domain`), este paso es más
   simple de lo que se pensaba originalmente: solo guardar y listar
   pendientes.
4. ✅ **Indicador/botón de subida por jornada** (`image-review-offline-sync`)
   — hecho (con subida SIMULADA al principio; REAL desde el paso 7, capa 6): una
   píldora por jornada con pendientes, encima de `GoToLatestMessageButton` en
   `MessageList`; aparece con el primer registro pendiente, sin lógica de
   conteo — la persona asignada decide cuándo presionarlo. Incluye
   `getPendingJornadas` (pendientes de cualquier día), progreso "Subiendo X de
   N", corte al salir del chat y la limpieza de índices huérfanos en
   `pending()`. Detalle en `image-review-offline-sync`.
   **Retirado el 2026-10-04 (cambio deliberado, ver paso 8)**: la píldora ya
   no está en `MessageList`; la misma lógica de subida vive en el "Subir" de
   `/review`.
5. **Pantalla de resumen por jornada/grupo** (`image-review-domain` +
   `image-review-roles`): reconciliación agregada (suma de totales del
   Revisor vs. suma de totales del Sumador, por jornada), alertas de
   descuadre, sin acumular entre días ni entre jornadas del mismo día.
   Esta pantalla es también donde vive la alerta de descuadre de dinero
   (reconciliación de sumas) y, por separado, el aviso de imágenes sin
   registrar (ver `image-review-domain` § "Reconciliación de dinero vs.
   imágenes sin registrar: dos señales separadas") — no un conteo previo
   en el indicador de subida. El detector de imágenes sin registrar usa
   el contador que publica el bot en `shift_image_counts`, no `count()` ni
   el máximo de `whatsapp_messages` (ver `image-review-domain.md`).
   **UI hecha** (menú "Resumen" en `ChatList` +
   ruta `/summary`, **solo para admin y superAdmin** — `canViewSummary`,
   decidido; Revisor y Sumador no la ven, ver `image-review-roles`;
   `SummaryPage` con selector de fecha y
   tarjetas por grupo y jornada, en `features/summary/`). Empezó con datos
   inventados (`MockSummaryRepository`, ya borrado); **desde el paso
   7, pieza d, lee datos reales** (ver "Pieza (d)" más abajo). **El Resumen mockeado ya incluye el aviso de imágenes sin
   registrar** (línea bajo cada rol, con `imagenesEnJornada` inventado en el
   mock con el formato real de `shift_image_counts`); falta cambiar solo la
   fuente por un `get` por id a esa colección.
6. **Integración Firebase con mocks** (`image-review-firebase-integration`):
   Cloud Function puente simulada, jornadas y números ganadores locales
   — para poder construir y probar la pantalla nueva de coincidencias
   sin depender del proyecto externo real. El enum `Shift` local se
   mantiene tal cual hasta el siguiente paso.
   **UI ya hecha con datos INVENTADOS** (página `/matches`, solo para
   `isAdmin`/`isSuperAdmin` vía `canViewMatches`; entrada "Coincidencias"
   en el menú de `ChatList`; `MockMatchesRepository` determinista por
   fecha, en `features/matches/`, ya borrado). **Desde el paso 7, pieza c, lee datos
   reales** (ver "Pieza (c)" más abajo).
7. **Conexión real a Firebase** (`image-review-firebase-integration`):
   una vez el usuario tenga acceso al proyecto externo, revisar el
   formato real de jornadas/números ganadores y reemplazar los mocks
   del paso 6 — varios puntos de esta skill quedaron explícitamente
   diferidos hasta ese momento (ver Pendientes globales).
   **Pieza (a), subida real de registros — capas 1-6 HECHAS, subida REAL
   cableada**. Capa 1: la ruta grupo -> jornada -> registros
   (`image_reviews/{chatJid}/jornadas/{fechaJornada}_{shiftKey}/registros/{messageId}_{rol}`,
   nombres provisionales) y el payload con `shiftKey` los arma
   `ImageReviewRecordModel.toUploadDocument()`.
   **Capa 2**: interfaz `ReviewUploadDatasource`
   (reemplaza el documento completo, idempotente, no lanza) y
   `FirestoreReviewUploader`, ambos en Dart puro y probados con un
   datasource falso.
   **Capa 3**: `FirestoreReviewUploadDatasource`
   (`doc(path).set(data)` sin `SetOptions`, timeout de 15 s por registro,
   todo error a `Left`), probada con una función de escritura falsa.
   **Capa 4**: `messageTimestamp` (int, ms UTC, tal
   cual) viaja del visor al registro (`int?`, esquema sigue en v1) y al
   payload; `registradoEn` se mantiene. Un registro viejo sin el campo no se
   sube hasta re-guardarlo desde el visor.
   **Capa 5, reglas de Firestore — PUBLICADAS el 2026-10-01** (HECHO,
   verificado por el usuario; empezaron como borrador):
   `firestore.rules.draft` (raíz del repo, no referenciado en
   `firebase.json`) es la copia de lo publicado a mano en la consola, que
   reemplaza todo el conjunto (por eso copia tal cual las reglas que ya
   había). Agrega create/update de
   `image_reviews/.../registros/{registroId}` (delete negado; la lectura
   de admin se agregó después, ver más abajo):
   sesión, claim `reviewRole`, `rol` == claim, ids de registro y de jornada
   coherentes con el payload, `shiftKey` asignable, tipos de las claves, y
   `messageTimestamp`/`chatJid` iguales a los de `whatsapp_messages`.
   Detalle de qué valida y qué no en `image-review-offline-sync` § "Ruta de
   la subida".
   **Antecedente: probado en la zona de pruebas de la consola el
   2026-10-01, antes de publicar, en parte**
   (claim simulado editando a mano la línea del claim en el editor; el
   simulador no deja editar la carga útil del token). PERMITIDO: create de
   un revisor con el documento correcto. RECHAZADO: `messageTimestamp`
   distinto del mensaje real, sin sesión, `rol` distinto del claim. NO
   PROBADO: el claim real de un token, `jornadaId` mal armado, `shiftKey`
   `outOfShift`, id sin sufijo de rol, `chatJid` distinto, mensaje
   inexistente, `delete`, `get` y el cliente real de la app. Nota: el
   simulador convirtió `registradoEn` ISO en fecha y la regla lo rechazó
   por `is string`; la primera escritura real confirmó después que la app
   lo manda como texto, y también verificó el claim real y el cliente real
   de la app.
   **Capa 6, subida REAL cableada** (decisión del usuario, sin bandera):
   `reviewUploadDatasourceProvider` construye
   `FirestoreReviewUploadDatasource` con el `firestoreProvider` de la app y
   `reviewUploaderProvider` devuelve siempre `FirestoreReviewUploader`. Solo
   se construye al confirmar "Subir" (`ReviewUploadNotifier._upload`). Cada
   fallo deja un `debugPrint` con el messageId y el tipo de `Failure`, sin
   payload ni chatJid. Hasta la publicación de las reglas (2026-10-01) la
   escritura se rechazaba con `permission-denied` y el registro quedaba
   pendiente. `SimulatedReviewUploader` se borró (HECHO).
   **Cambio del modelo del registro — HECHO** (antes de la primera
   escritura real; decisión del usuario): el `codigo` pasa a ser **uno por
   imagen** (`ImageReviewForm.codigo`, un solo campo "Código" arriba de
   las tarjetas, obligatorio para los dos roles) y cada comprobante queda
   `{numeros, total, loteria}`, con `loteria` texto libre **opcional**
   ("Lotería (opcional)", dónde se compró el boleto; sin relación con los
   ganadores ni la reconciliación). Esquema sigue en v1 (`codigo` ausente
   → null; un `codigo` dentro de un comprobante viejo se ignora); un
   registro sin `codigo` no se sube hasta re-guardarlo desde el visor
   (abre con el código vacío). Reglas, Resumen y Coincidencias sin
   cambios. Detalle en `image-review-domain` (vocabulario y regla 6) y
   `image-review-offline-sync`.
   **PENDIENTES (no decididos)**: validar `codigo` y `loteria` en las
   reglas (hoy no se validan); si la lotería pasa a ser una lista cerrada.
   (El aviso para los registros viejos que no se pueden subir se descartó por decisión del usuario: son datos de prueba.)
   **Reglas publicadas y primera escritura real — HECHO (verificado por el
   usuario el 2026-10-01)**: reglas vigentes desde ese día, 7:37 p.m., con
   el contenido de `firestore.rules.draft`. Primera escritura real: 4
   documentos de **PRUEBA** en producción (jornadas `2026-10-01_afternoon2`
   y `2026-10-01_night1`, Revisor y Sumador en cada una, dos cuentas
   distintas); formato confirmado en la consola (`codigo` arriba,
   comprobantes `{numeros, total, loteria}`, `registradoEn` texto, `total`
   int64, `messageTimestamp` entero, ceros a la izquierda conservados,
   `fechaJornada`/`shiftKey` coherentes con la hora de Colombia); claim
   `reviewRole` real y comparación contra `whatsapp_messages` verificados.
   En la zona de pruebas, un usuario sin claim de admin no lee `registros`
   ni `shift_image_counts`. Los 4 documentos de prueba fueron borrados por el usuario desde la consola el 2026-10-04.
   Detalle en `image-review-offline-sync` (capas 5 y 6).
   Siguen **PENDIENTES** (detalle en `image-review-offline-sync` § "Ruta de
   la subida"): si conviene subir el
   esquema a v2 (versiones antiguas de la app en caché), los casos de escritura nunca
   probados en la zona de pruebas,
   si validar `reviewShifts` o `allowedGroups`, reglas de Storage,
   verificación de conexión antes de subir, si una escritura en
   cola del SDK web llega tarde después de un timeout,
   mensajes de error visibles en español en la interfaz, nombres definitivos de las
   colecciones, si `fechaJornada`
   usa `toLocal()` o UTC-5 (ahora es parte de la ruta), límites de tamaño
   (tampoco los imponen las reglas).
   **Acceso al Resumen — HECHO**: `/summary` y su entrada "Resumen" del
   menú solo para admin y superAdmin (`canViewSummary`, misma regla que
   `canViewMatches` pero separada); el resto va a `/home`. **PENDIENTES**:
   si Revisor o Sumador deben ver sus propias sumas, una Cloud Function
   (toca `functions/`); el desfase de claims (se leen solo al iniciar
   sesión: un admin al que le quiten el rol sigue viendo la pantalla hasta
   que se renueve el token).
   **Lectura de `image_reviews` — DECIDIDO por el usuario**: solo la leen
   cuentas con claim `admin` o `superAdmin`; Revisor y Sumador no leen nada
   de `image_reviews` (sus registros siguen en local). La regla está
   publicada desde el 2026-10-01 (ver más abajo).
   **Pieza (d), Resumen real — capa 1 HECHA y CONECTADA**: capa de datos
   en `features/summary/data/` (nombres provisionales), probada con
   datasources falsos. Tres datasources en Dart puro con su clase Firestore
   (constructor con `FirebaseFirestore` y `.withReader` para tests; nunca
   lanzan; `FirebaseException` → `mapFirestoreError`): registros del día
   (`collectionGroup('registros').where('fechaJornada', ...)`), contadores
   del bot del día (`shift_image_counts.where('shiftDate', ...)`) y nombre
   del grupo (`group_stats/{chatJid}`). Un documento con un campo faltante,
   un tipo incorrecto, un `shiftKey` desconocido u `outOfShift` (o un `rol`
   desconocido) hace que la lectura devuelva `Left` con su id: nunca se
   omite. `FirestoreSummaryRepository` arma un `JornadaSummary` por cada
   (grupo, jornada) con contador o registros ese día (ver
   `image-review-domain`, "Cómo se arma el Resumen real"). Providers en
   `real_summary_providers.dart` (`realSummaryRepositoryProvider` y los tres
   datasources).
   **Conexión — HECHA (decisión del usuario)**: `summaryRepositoryProvider`
   devuelve `ref.watch(realSummaryRepositoryProvider)`: el Resumen lee
   datos reales (registros de `image_reviews`, contadores de
   `shift_image_counts` y nombres de `group_stats`), solo para admin y
   superAdmin, con la caché de 5 minutos. `MockSummaryRepository` se
   borró (HECHO).
   Un `Left` deja un `debugPrint` en `jornadaSummariesProvider`: los errores
   de Firestore y de permisos con su texto completo (si falta un índice,
   trae el enlace para crearlo), los demás solo con el tipo (su texto puede
   nombrar un registro). `SummaryPage` no cambió: muestra el texto completo
   del `Failure` con "Reintentar". **HECHO (verificado por el usuario el
   2026-10-02)**: el Resumen real FUNCIONA con una cuenta admin (leyó los
   registros, los contadores y los nombres); un admin real puede leer los
   registros y la consulta de grupo de colecciones funciona. El índice de
   grupo de colecciones sobre `fechaJornada` (ascendente) se creó desde la
   consola, como exención de `registros.fechaJornada`, con el enlace que
   trajo el error. Coincidencias lee datos reales desde la
   pieza c (ver más abajo).
   **Caché del Resumen — HECHA** (hoy sobre el repositorio real): `SummaryCache`
   en memoria, por fecha (`fechaJornadaDe`), TTL de 5 minutos
   (`summaryCacheTtl`), solo éxitos (un `Left` nunca se guarda), una sola
   lectura por fecha a la vez, máximo 10 fechas (sale la más antigua).
   `jornadaSummariesProvider` pasa por ella. Botón "Actualizar" en la barra
   de `SummaryPage` y "Reintentar" del error: invalidan la fecha elegida y
   van a la fuente (`reloadJornadaSummariesProvider`). Nombres de grupo:
   `CachedGroupNameDatasource` guarda los encontrados toda la sesión (no
   los ausentes ni los errores), aplicado solo en `real_summary_providers.dart`.
   **PENDIENTES (no decididos)**: la caché no se comparte entre pestañas ni
   sesiones; un registro subido después puede tardar hasta 5 minutos en
   aparecer (el botón "Actualizar" lo evita).
   **Reglas de lectura de admin — PUBLICADAS el 2026-10-01** (en la zona de
   pruebas, un usuario sin claim de admin no lee `registros` ni
   `shift_image_counts`; la lectura de un admin real quedó verificada el
   2026-10-02 con el Resumen):
   `isAdmin()` (claims `admin` o `superAdmin` leídos con `get`), `match
   /{path=**}/registros/{registroId}` solo lectura (sirve a la consulta de
   grupo; el nombre `registros` aplica a toda colección con ese nombre) y
   `shift_image_counts` con lectura de admin y escritura negada.
   **`functions/set-admin.js` — HECHO**: ahora fusiona los claims existentes (`{...claimsActuales, admin: true, superAdmin: true}`, leídos del `UserRecord` de `getUserByEmail`) en vez de reemplazarlos, así que ya no borra `reviewRole`; tests en `functions/test/setAdmin.test.js`. **SUPOSICIÓN**: un claim que ya se hubiera perdido por una corrida anterior del script no se recupera solo.
   **PENDIENTES (no decididos)**: `lastIndex` puede ser mayor que las imágenes reales; el costo en lecturas por consulta (hasta unas 3600; la caché de 5 minutos evita repetirla); el desfase de claims
   (se leen solo al iniciar sesión); no hay
   contadores de días anteriores a la publicación inicial (ver
   `image-review-domain`); el día se arma con `fechaJornadaDe` (`toLocal()`)
   y `shiftDate` es UTC-5 fijo; y lo ya pendiente (qué colección de
   resultados manda para las coincidencias ya se decidió, ver "Pieza (c)").
   **Pieza (c), Coincidencias real — HECHA y CONECTADA** (decisiones del
   usuario): `matchesRepositoryProvider` devuelve
   `ref.watch(realMatchesRepositoryProvider)` (`FirestoreMatchesRepository`,
   nombres provisionales). Tres datasources nuevos en
   `features/matches/data/datasources/` (Dart puro + clase Firestore con
   `.withReader`; nunca lanzan; `FirebaseException` → `mapFirestoreError`; un
   documento malformado da `Left` con su id): registros del **Revisor** del
   día (`collectionGroup('registros')` por `fechaJornada` y `rol`), números
   ganadores del día (`winning_numbers/{fecha}`, campo `numbers`, nombre y
   forma **PROVISIONALES** en una sola constante; documento ausente = lista
   vacía) y el mensaje por id (`whatsapp_messages`: `senderName` y
   `localTime`). El nombre del grupo reutiliza el
   `groupNameDatasourceProvider` del Resumen, con su caché (sin documento →
   el `chatJid`; error → `Left`). Solo admin y superAdmin leen
   `image_reviews`.
   - **Comparación**: los ganadores de una fecha se comparan contra los
     números del Revisor de **TODAS las jornadas y grupos** de esa fecha;
     solo cuenta el número (`findMatches`; desde la pieza de 3 y 4 cifras,
     ver "Pieza b1.1" más abajo). Solo las
     coincidencias leen su mensaje (una vez por `messageId`) y su grupo (una
     vez por `chatJid`); cualquier lectura fallida → `Left`.
   - **Pantalla**: siempre una lista por jornada (las del día: domingo solo
     `holiday`, si no mañana, tarde 1, tarde 2 y noche 1, más cualquier otra
     con registros del Revisor), cada una con los mismos ganadores del día;
     sin coincidencias: "Todavía no hay ganadores". El vacío de página queda
     solo para un día sin jornadas. Sin ganadores, no se leen registros.
   - Se quitó `messageEdited` (de `MatchEntry` y del diálogo de detalle).
     **"Ver imagen" activado** (HECHO: `realImageEnabled` en `true` por
     defecto, carga la imagen real desde el `storagePath` del registro).
   - Log: `failureLogLine(tag, failure)` en `core/errors/` (Firestore y
     permisos con su texto completo, el resto solo el tipo); un `Left`
     imprime `[COINCIDENCIAS] falló (...)` y el Resumen usa la misma función
     con `RESUMEN`. `MockMatchesRepository` se borró (HECHO).
   - **Regla de `winning_numbers` — PUBLICADA el 2026-10-02** (HECHO,
     verificado por el usuario): lectura para `isAdmin()`, escritura
     negada; copia en `firestore.rules.draft`. La colección existe desde
     el 2026-10-03: la escribe la función puente desplegada.
   - **Coincidencias abrió sin error con una cuenta admin** (HECHO,
     verificado por el usuario el 2026-10-02), mostrando "Todavía no hay
     ganadores".
   **Función puente (pieza b) — DECIDIDO por el usuario**:
   el número de `manual_lotteries` reemplaza al de `resultados_loterias`
   cuando es la misma lotería y la misma fecha; una lotería que solo está
   en la manual cuenta como un número más; solo importa el número (la serie
   se ignora); la función normaliza tildes y mayúsculas entre colecciones
   (a confirmar con datos reales). Función programada **cada hora**, que
   procesa **hoy y ayer en hora de Bogotá** (la manual se corrige después),
   **sin historial** y **sin bot**. El usuario **autorizó** trabajar en
   `functions/` para esta función y desplegarla cuando esté lista.
   **Pieza b1 — HECHA**: la mezcla, como función pura sin Firebase
   (`mergeWinningNumbers` en `functions/winningNumbers.js`, con tests
   `node:test`; no exportada en `index.js`). Devuelve `{numbers,
   discarded}`: `numbers` son textos de 3 o 4 cifras (desde b1.1), ceros a
   la izquierda conservados, sin duplicados, en orden ascendente;
   `discarded`, lo que no lo es (o no tiene nombre ni slug, `sin-loteria`),
   con su lotería y el motivo. La clave de emparejamiento (`lotteryKey`)
   es PROVISIONAL. Detalle en `image-review-firebase-integration`
   ("Función puente de ganadores (pieza b)").
   **Pieza b1.1 — HECHA** (solo lógica pura y tests con datos falsos):
   forma real de las entradas documentada (`manualList` = `doc.data().list`
   de `manual_lotteries/{yyyy-MM-dd}`, sin usar `date`). **DECIDIDO por el
   usuario**: ganadores de 3 o 4 cifras en el mismo `numbers` ("Cash
   three" cuenta); por ahora un ganador de 3 cifras se compara solo con
   boletos de 3; la regla de `findMatches` (boleto de 4 = ganador completo,
   boleto de 3 = últimas 3 del ganador de 4, otras longitudes se ignoran
   sin aviso, aciertos de 3 y de 4 como coincidencias separadas) está
   decidida e **IMPLEMENTADA** (ver abajo); una entrada sin nombre ni slug no es
   válida; el slug sigue PROVISIONAL, con un alias **DECIDIDO por el
   usuario e IMPLEMENTADO**: `doramaña` (manual) se empareja con
   `dorado_mañana` (automática) mediante `LOTTERY_KEY_ALIASES` en
   `lotteryKey`, respaldado por 118 fechas en una lectura de
   `whats-apuestas` del 2026-10-03; los demás pares se descartan por
   aparecer en una sola fecha; la escritura será solo si cambió (pieza b2);
   un boleto de 3 cifras puede coincidir a la vez con un ganador de 3 (p.
   ej. "Cash three") y con las últimas 3 de un ganador de 4 ("606" con
   "606" y con "4606"): la app solo muestra coincidencias y los revisores
   deciden si corresponde el premio doble; si el resultado de una fecha
   sale vacío, el handler no escribe nada y deja lo que había (si se
   borran los ganadores, los revisores no los revisan).
   **Pieza `findMatches` (3 y 4 cifras) — HECHA**: **DECIDIDO por el usuario e IMPLEMENTADO**: tras `trim` en ambos lados, sin normalizar ni quitar ceros a la izquierda, un boleto de 4 cifras coincide si es igual a un ganador de 4; uno de 3, si es igual a las últimas 3 de un ganador de 4 o a un ganador de 3 (las dos vías a la vez); un ganador de 3 nunca coincide con un boleto de 4; boletos y ganadores de otra longitud se ignoran sin aviso; una entrada por registro, nunca dos veces
   ("606" contra "606" y "4606" sale una sola vez; la entrada no lleva el
   ganador). Tests en `test/unit/matches/find_matches_test.dart`.
   **Pieza b2 — HECHA** (código y tests con datos falsos; desplegada el
   2026-10-03, ver abajo). **DECIDIDO por el usuario**: disparador cada 60 minutos, hoy y
   ayer en hora de Bogotá, escribir solo si cambió, un resultado vacío no
   escribe nada. Sobre `discarded`: comportamiento actual de la pieza b2: discarded solo se registra en el log; qué hacer con discarded sigue PENDIENTE (no decidido). `functions/winningNumbersSync.js`
   (sin `firebase-admin`, dependencias por parámetro):
   `syncWinningNumbers` lee `resultados_loterias/{fecha}` y
   `manual_lotteries/{fecha}` (ausente = vacío), mezcla con
   `mergeWinningNumbers`, compara con `winning_numbers/{fecha}` como listas
   ordenadas y escribe `{numbers}` solo si cambió; una fecha que falla se
   registra (id y tipo de error) sin escribirla y se sigue con la otra;
   devuelve y registra un resumen por fecha (`escrita`, `sin-cambios`,
   `omitida-vacia`, `error`). Fecha de Bogotá con UTC-5 fijo.
   `runWinningNumbersSync` maneja el secreto (falta o JSON inválido → log
   con el nombre, sin el contenido, y no escribe). En `index.js`, solo un
   import y el export `syncWinningNumbers` (`onSchedule`, `"every 60
   minutes"`, `timeZone: "America/Bogota"`, sin región, `secrets:
   [defineSecret("WHATS_APUESTAS_KEY")]`, nombre PROVISIONAL) con una
   segunda app de Admin "whats-apuestas" para leer. **SUPOSICIÓN**: el
   documento lleva solo `numbers`. Detalle en
   `image-review-firebase-integration` ("Pieza b2").
   **Función puente DESPLEGADA y corriendo — HECHO (verificado por el
   usuario el 2026-10-03)**: secreto `WHATS_APUESTAS_KEY` creado en
   `whatsapp-pro-3d483` (versión 1); deploy con `firebase deploy --only
   functions:syncWinningNumbers` (solo esa función, sin `--force`) hacia las
   00:39 de Bogotá: v2 programada, `us-central1`, 256 MB, `nodejs24`; el CLI
   habilitó Cloud Scheduler y dio acceso al secreto a la cuenta de servicio
   de Compute por defecto; los 10 callables no se redesplegaron
   (`functions:list` los muestra intactos) y `setReviewAssignment` ya no
   está en producción. Primera corrida (forzada a las 00:44): `escrita` para
   2026-10-03 y 2026-10-02, sin errores; la llave lee el ERP, la función
   escribe `winning_numbers` con el formato esperado ("606" incluido, ceros
   a la izquierda, orden de texto) y la entrada manual vacía del 2026-10-02
   se descartó con `sin-loteria`. El cron corre solo (02:44, 03:44 y 04:44,
   `sin-cambios`): queda CONFIRMADO que Cloud Scheduler acepta `"every 60
   minutes"`. El aviso `sin-loteria` se repite en cada corrida mientras
   exista esa entrada manual vacía (esperado).
   **DECIDIDO por el usuario**: los resultados del día D valen hasta las
   5:30 a.m. (Bogotá) del día D+1; la función no cambia (procesa hoy y ayer)
   y no se agrega ninguna regla de horas.
   **OBSERVADO (HECHO, sin causa)**: en una lectura del 2026-10-03, 258 de
   259 documentos de `resultados_loterias` tienen su última actualización a
   las 13:30 de Bogotá, y cada documento se crea a las 20:30 del día
   anterior. `resultados_loterias/2026-10-03` tuvo 20 entradas a las 20:30,
   32 a las 06:30 y 9 a las 13:30: la actualización de las 13:30 reemplaza
   el contenido (corrige la nota anterior de 20 entradas);
   `resultados_loterias/2026-10-02`, `updatedAt` 13:30 y 9 entradas;
   `manual_lotteries/2026-10-03` no existía en la primera lectura. Por eso,
   antes de las 13:30, `winning_numbers/2026-10-03` contenía resultados de
   otra jornada y `winning_numbers/2026-10-02` tiene solo los 9 de las 13:30. "Play four día" figuraba como 5362 en una
   lectura anterior y como 9252 después, sin explicación. **SUPOSICIÓN**
   (no verificada): que quien escribe `resultados_loterias` arma el id con
   la fecha en UTC. Detalle en `image-review-firebase-integration`.
   **PENDIENTES de la función puente (no decididos)**: hasta las 13:30 de
   su fecha, el documento de la API trae datos de otra jornada, y por eso
   `winning_numbers` de ese día puede mostrar números que no son de ese día
   hasta esa hora (el usuario dijo que los ganadores se revisan al día
   siguiente); qué hacer con `discarded` (hoy solo se registra en el log).
   **PENDIENTES (no decididos)**: el índice de grupo de colecciones sobre
   `fechaJornada` y `rol` (el enlace sale del error de la primera consulta
   con ganadores, en el log `[COINCIDENCIAS] falló (firestore): ...`);
   caché; costo en lecturas; que "Ver imagen" no se probó con una imagen
   real (las reglas de Storage no están en el repo); y lo ya pendiente.
   **Pieza (e), tabla de jornadas ÚNICA — HECHA** (decisión del usuario):
   el horario de `jornadas` de `whats-apuestas` (leído el 2026-09-30) rige
   en toda la app, para todas las fechas y todos los mensajes; la tabla
   vieja y el corte (`newShiftsEffectiveFromMs`, `usesNewShiftTable`,
   `shiftNamesAt`, `effectiveFromMs`) se retiraron. `shiftNames` tiene
   ahora las etiquetas ACTUALES y las viejas están en `legacyShiftNames`
   (solo para reconocer lo guardado y como respaldo de night2). night2 solo
   queda como valor del enum: `getCurrentShift` nunca lo devuelve, el
   diálogo de horarios no lo ofrece y el panel de control no tiene su fila.
   Los huecos se ven en el visor ("Fuera de jornada X") pero no cuentan
   para reportes. Detalle en `image-review-domain` ("Jornadas: una sola
   tabla") y en `image-review-firebase-integration` ("Tabla definitiva").
   **HECHOS verificados por el usuario el 2026-10-02**: la regla de
   `winning_numbers` está publicada; Coincidencias abre sin error con la
   cuenta admin y muestra "Todavía no hay ganadores"; el Resumen real
   funciona con la cuenta admin (ver "Pieza (d)").
   **PENDIENTES (no decididos)**: actualizar el BOT con los mismos rangos y
   sin night2 (en su repo; hasta entonces `shift_image_counts` sigue la
   tabla vieja y el "imágenes en la jornada" del Resumen puede estar
   desfasado en los bordes); retirar night2 de `ASSIGNABLE_SHIFTS` en
   `functions/`; caché de la PWA tras desplegar (fuente de festivos y
   horario del ERP que cambia sin aviso, para la app: resueltos por la pieza
   2 de horarios dinámicos, más abajo); los mensajes ya guardados se
   reclasifican con la tabla única; que Coincidencias, cuando haya
   ganadores, probablemente pida un índice sobre `rol`; y lo ya pendiente.
   **Horarios dinámicos, pieza 1 — HECHA (código y tests; NO desplegada)**
   (decisión del usuario, 2026-10-03): el mismo disparador programado de los
   ganadores, después de ellos y con la misma conexión y el mismo secreto,
   copia `jornadas` del ERP a una colección `jornadas` de nuestro proyecto
   (nombre PROVISIONAL): réplica exacta (mismos ids y los 7 campos, tal
   cual), escribe solo si cambió o no existe, valida solo el formato de
   `startTime`/`endTime`, nunca borra, cero documentos del ERP no escribe
   nada; ganadores y jornadas aislados en try/catch separados.
   `functions/jornadasSync.js` + tests en `functions/test/jornadasSync.test.js`;
   bloque de reglas de `jornadas` en `firestore.rules.draft`, **NO
   PUBLICADO** (hasta publicarlo la app no puede leer la colección).
   DECIDIDO: "Mañana" vale para las mañanas de todos los días excepto
   domingos y festivos, que usan `festivos`. Conversión de ids y detalle en
   `image-review-firebase-integration` ("Réplica de jornadas").
   **SUPOSICIÓN**: los horarios que se usan son siempre `startTime` y
   `endTime`.
   **Festivos en Firebase — HECHO (2026-10-03)**: `festivos_colombia`, diez
   documentos (`"2026"` a `"2035"`, campo `fechas`, lista `yyyy-MM-dd`; 18
   por año, 2030 con 17), cargados con el Admin SDK desde una lista generada
   con reglas y revisada por el usuario, y verificados releyéndolos.
   **Horarios dinámicos, pieza 2 — HECHA (código y tests; sin desplegar)**
   (DECIDIDO por el usuario e IMPLEMENTADO, opción A, versión simple): la app
   lee `jornadas` y `festivos_colombia` y clasifica con ellos; **la tabla
   fija actual es el respaldo**. `shifts.dart` guarda una sola tabla activa
   (`ShiftTable`, inicializada con `fixedShiftTable`; `replaceShiftTable`,
   `restoreFixedShiftTable` solo para tests); `shiftLastMinute` sale de los
   rangos; `isHolidayOrSunday` hace que un festivo se comporte como un
   domingo (también en `_shiftsOfDay` de Coincidencias); etiquetas fijas;
   zona horaria sin cambios. Datasource y cargador en
   `lib/features/shift_schedule/` (lectura única por sesión, disparada con
   `ref.listen` en `app.dart`, sin reintentos ni timeout; falla →
   `[JORNADAS] falló (...)` y tabla fija; tabla distinta → reemplaza e
   invalida `shiftStatsProvider`). Regla de `festivos_colombia` en
   `firestore.rules.draft`, **NO PUBLICADA**. Limitaciones aceptadas: los
   mensajes ya cargados mantienen su etiqueta hasta cambiar de chat o de
   filtro, y lo guardado antes del deploy puede quedar con etiquetas
   desfasadas. Detalle en `image-review-firebase-integration` ("Lectura en
   la app").
   **PENDIENTES (no decididos)**: publicar a mano las reglas de `jornadas` y
   `festivos_colombia` (confirmar antes que la consola coincide con el
   borrador; mientras no se publiquen, la app usa la tabla fija); pieza 3
   (el bot sigue con su tabla vieja); el texto de las etiquetas no se
   actualiza si el ERP cambia un horario (cosmético); la zona horaria del
   dispositivo para los festivos; qué hacer con `pendingApproval: true` o
   `proposed*` (hoy se ignoran); desplegar.
   **Limpieza — HECHA**: se borraron `MockSummaryRepository`,
   `MockMatchesRepository` y `SimulatedReviewUploader`, con sus tests
   propios; el test del menú (`custom_popup_menu_logout_button_test.dart`)
   usa repositorios falsos vacíos dentro del propio test.

8. **Flujo "Llenar formularios" — HECHO (2026-10-04, CAMBIO DELIBERADO
   pedido por los usuarios; sin desplegar)**: contradice a propósito tres
   decisiones anteriores: la cápsula de subida en el chat (paso 4), el
   formulario en el visor del chat (paso 2) y el cierre de jornada sin
   contar imágenes (`image-review-domain`). Capas, todas con tests:
   1. `jornadaImagesProvider`: imágenes de una jornada de un chat en un día,
      de la PRIMERA a la ÚLTIMA (día completo con `fetchByDateRange`; en vivo
      solo si el día es hoy; sin reintento automático; los huecos entre
      jornadas quedan fuera).
   2. `ImageDetailPage` reutilizable (`items`, `reverse`, `paginate`,
      `showClose`/`onClose`/`closeLabel`, `actions`, `reviewForm`).
   3. Pantalla `/review` (`ReviewSessionPage`) con sesión de llenado en
      memoria (`reviewSessionProvider`) y guard en `computeAuthRedirect` (no
      se sale salvo con "Cerrar" o recargando); "Subir" (`PendingUploadPill` +
      `ReviewUploadNotifier`), "Cerrar" (solo con TODAS las imágenes con
      registro guardado; con la lista vacía también) y aviso con ancho < 840.
   4. Botón "Llenar formularios" (`FillFormsButton`) en `MessageList` y su
      diálogo (fecha con flechas, jornadas asignadas que aplican al día).
   5. Limpieza: sin cápsula; el visor del chat volvió a ser solo visor
      (`reviewForm: false`); corregir un registro (también uno subido) solo
      se hace desde `/review`.
   Detalle en `image-review-roles` ("Pantalla de llenado `/review`"),
   `image-review-domain` ("Cierre de jornada") e `image-review-offline-sync`.
   El `debugPrint` temporal de lecturas se quitó tras medir (32 mensajes
   en `holiday` del 2026-10-04). `CACHE_NAME` subió a `whatsapp-monitor-v5`.
   **PENDIENTE**: desplegar el hosting (primero se muestra al cliente en un
   canal de vista previa).

## Checklist antes de pasar a la siguiente pieza

- [ ] ¿Se leyó la skill correspondiente completa (no solo el título)?
- [ ] ¿Hay algo de lo que se va a implementar marcado como "Zona gris"
      en esa skill? Si sí, confirmarlo con el usuario antes de escribir
      código, no asumir.
- [ ] ¿La pieza se puede probar de forma aislada (widget test, o
      manualmente) antes de seguir con la siguiente?
- [ ] `flutter analyze` y `flutter test` limpios (ver deuda técnica
      conocida en `PROJECT_DOCUMENTATION.md` — el fallo de
      `package:web` en tests ya es conocido, no es un problema nuevo).
- [ ] Si algo de lo implementado **contradice** lo que dice una skill
      (porque el código real resultó distinto a lo asumido), **actualizar
      esa skill en el mismo momento** — no dejarlo para después, así la
      próxima sesión no repite el error.

## Relación con los plugins instalados (no duplicar su trabajo)

Estas skills de proyecto se enfocan en **negocio y proceso específico
de este feature**. No repiten lo que ya cubren los plugins instalados:

- `dart-flutter` → buenas prácticas generales de Dart/Flutter (dejarlo
  a ese plugin, no reescribir convenciones de Dart aquí).
- `code-review` → revisión de código una vez escrito.
- `firebase` → convenciones generales de Cloud Functions/Firestore (las
  reglas de *este* feature específico sí viven en
  `image-review-firebase-integration`, pero patrones genéricos de
  Firebase no).
- `frontend-design` / `ui-design` (skill de proyecto) → estética y
  patrones de UI generales; las restricciones de UI *específicas* de
  este feature (tablet/PC, ubicación del botón de subida, etc.) sí
  viven en las skills de este feature.

## Pendientes globales que bloquean partes de la implementación

Lista consolidada de las "Zona gris" que quedan en las cuatro skills,
para tener de un vistazo qué falta resolver antes de poder implementar
todo sin adivinar. Se actualiza a medida que se van resolviendo (borrar
de aquí y de la skill correspondiente cuando el usuario confirme):

- **Validar `reviewForm = 840` en dispositivos reales** (tablet
  vertical/horizontal, laptop) (`image-review-roles`) — el valor ya está
  adoptado en `AppBreakpoints`, falta comprobarlo fuera de los tests.
- **`sqflite`/`drift` vs. `Hive`** (`image-review-offline-sync`) —
  decisión libre, a tomar en Claude Code; no hay nada existente que
  condicione la elección.
- **Función puente de ganadores** (`image-review-firebase-integration`):
  el mecanismo ya está decidido (polling programado cada hora, hoy y ayer
  en hora de Bogotá, sin historial) y la mezcla está hecha (piezas b1 y
  b1.1: 3 o 4 cifras, `sin-loteria`; decididos la escritura solo si
  cambió y no escribir nada si el resultado sale vacío) y el handler
  programado está **desplegado y corriendo cada hora** desde el 2026-10-03
  (pieza b2); alias `doramaña` → `dorado_mañana` decidido e implementado
  (118 fechas). Falta: qué hacer con `discarded` y con los números de otra
  jornada que trae el documento de la API hasta las 13:30 de su fecha. (El
  formato de las jornadas ya se vio y se decidió una tabla fija en código,
  2026-09-30.)
- **Tabla única de jornadas** (`image-review-domain`): actualizar el bot
  con los mismos rangos y sin night2 (en su repo), retirar night2 de
  `ASSIGNABLE_SHIFTS` en `functions/` y caché de la PWA tras desplegar.
- **Horarios dinámicos** (`image-review-firebase-integration`, "Réplica de
  jornadas" y "Lectura en la app"): piezas 1 y 2 hechas y sin desplegar,
  festivos cargados en `festivos_colombia`; faltan publicar las reglas de
  `jornadas` y `festivos_colombia`, la pieza 3 (bot), desplegar, el texto de
  las etiquetas con horas fijas, la zona horaria del dispositivo para los
  festivos y el significado de `pendingApproval`/`proposed*`.
- **Calidad de conexión en la subida real** (`image-review-offline-sync`,
  paso 7) — el timeout por registro ya existe (15 s, capa 3); falta decidir
  si además se verifica la conexión antes de subir, y qué pasa si una
  escritura en cola del SDK web llega después del timeout.
- **Qué pasa si le quitan el rol a alguien con registros locales sin
  subir** (`image-review-roles`) — queda como decisión operativa del
  superAdmin, no resuelta por la app.