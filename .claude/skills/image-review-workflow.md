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
   **UI ya hecha con datos INVENTADOS** (menú "Resumen" en `ChatList` +
   ruta `/summary`, **solo para admin y superAdmin** — `canViewSummary`,
   decidido; Revisor y Sumador no la ven, ver `image-review-roles`;
   `SummaryPage` con selector de fecha y
   tarjetas por grupo y jornada, alimentada por `MockSummaryRepository`,
   determinista por fecha, en `features/summary/`). **Sigue pendiente
   conectar datos reales** (reemplazar el mock por un `SummaryRepository`
   real: subida real a Firestore, paso 7, o el mecanismo de lectura
   cruzada). **El Resumen mockeado ya incluye el aviso de imágenes sin
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
   fecha, en `features/matches/`). **Sigue pendiente conectar datos
   reales** (paso 7: reemplazar el mock por un `MatchesRepository`
   real; de dónde lee —y si hay o no lectura directa de Firestore— se
   define en el paso 7).
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
   había). Su comentario de encabezado todavía dice "BORRADOR... no se
   despliega" (también en lo publicado): hay que corregirlo. Agrega create/update de
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
   pendiente. `SimulatedReviewUploader`
   queda sin cablear (candidato a borrar).
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
   reglas (hoy no se validan); si la lotería pasa a ser una lista cerrada;
   un aviso visible
   para los registros viejos que no se pueden subir (la píldora los sigue
   contando).
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
   ni `shift_image_counts`. **Hay que BORRAR los 4 documentos de prueba
   desde la consola** antes de desplegar el hosting o de que otra persona
   use el Resumen. Detalle en `image-review-offline-sync` (capas 5 y 6).
   Siguen **PENDIENTES** (detalle en `image-review-offline-sync` § "Ruta de
   la subida"): aviso visible para los registros viejos que no se pueden
   subir (y que la píldora los sigue contando), si conviene subir el
   esquema a v2 (versiones antiguas de la app en caché), borrar los 4
   documentos de prueba, corregir el encabezado de `firestore.rules.draft`
   y republicar cuando cambie otra regla, los casos de escritura nunca
   probados en la zona de pruebas, probar la lectura de un admin real
   conectando el Resumen,
   si validar `reviewShifts` o `allowedGroups`, reglas de Storage,
   verificación de conexión antes de subir, si una escritura en
   cola del SDK web llega tarde después de un timeout,
   mensajes de error visibles en español en la interfaz, nombres definitivos de las
   colecciones, cómo lee
   Coincidencias entre grupos (consulta de grupo de colecciones o Cloud
   Function), si `fechaJornada`
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
   **Pieza (d), Resumen real — capa 1 HECHA, NO conectada**: capa de datos
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
   datasources) que **ningún código lee**: `summaryRepositoryProvider` sigue
   en `MockSummaryRepository`.
   **Caché del Resumen — HECHA** (funciona ya con el mock): `SummaryCache`
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
   `shift_image_counts`; la lectura de un admin real no está verificada):
   `isAdmin()` (claims `admin` o `superAdmin` leídos con `get`), `match
   /{path=**}/registros/{registroId}` solo lectura (sirve a la consulta de
   grupo; el nombre `registros` aplica a toda colección con ese nombre) y
   `shift_image_counts` con lectura de admin y escritura negada.
   **PENDIENTES (no decididos)**: probar la lectura de un admin real
   conectando el Resumen; borrar antes los 4 documentos de prueba; la
   consulta de grupo de colecciones real; crear el índice de grupo de
   colecciones sobre
   `fechaJornada` en `registros` desde la consola cuando falle la primera
   consulta real; el desfase de claims (se leen solo al iniciar sesión);
   qué hacer con `functions/set-admin.js`, que reemplaza los claims sin
   fusionarlos (borraría `reviewRole`); cambiar
   `summaryRepositoryProvider` al repositorio real (una línea, con
   autorización); costo en lecturas (hasta unas 3600 por consulta real; la
   caché de 5 minutos evita repetirla); `lastIndex` puede ser mayor que las imágenes reales; no hay
   contadores de días anteriores a la publicación inicial (ver
   `image-review-domain`); el día se arma con `fechaJornadaDe` (`toLocal()`)
   y `shiftDate` es UTC-5 fijo; qué colección de resultados manda para las
   coincidencias; y lo ya pendiente.
   **Jornadas — tabla definitiva, código HECHO, corte SIN fijar**: se leyó
   una vez `jornadas` de `whats-apuestas` (2026-09-30) y el usuario decidió
   usar ese horario como tabla fija en código, sin lectura dinámica. Tabla
   vieja y nueva coexisten en `shifts.dart`; `newShiftsEffectiveFromMs`
   sigue en `null` (tabla vieja en toda la app) hasta que el usuario lo fije
   el día del despliegue. night2 retirado de la tabla nueva; los huecos se
   ven en el visor ("Fuera de jornada X") pero no cuentan para reportes.
   Detalle en `image-review-domain` ("Jornadas: tabla vieja, tabla nueva y
   corte") y en `image-review-firebase-integration` ("Tabla definitiva").
   **PENDIENTES**: fecha fija del corte y despliegue coordinado con el bot;
   actualizar el bot (rangos y claves de `shift_image_counts`) en su repo;
   retirar night2 de `ASSIGNABLE_SHIFTS` en `functions/`; fuente de
   festivos; caché de la PWA tras el despliegue.

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
- **Dos puntos diferidos del proyecto externo de Firebase**
  (`image-review-firebase-integration`): mecanismo de recepción de números
  ganadores (webhook vs. polling) y el contrato completo de la Cloud
  Function puente. El usuario dijo que los revisamos juntos — no intentar
  adivinarlos antes. (El formato de las jornadas ya se vio y se decidió
  una tabla fija en código, 2026-09-30.)
- **Corte de la tabla de jornadas** (`image-review-domain`): fecha fija de
  `newShiftsEffectiveFromMs` y despliegue coordinado con el bot (rangos y
  claves de `shift_image_counts` en su repo), retirar night2 de
  `ASSIGNABLE_SHIFTS` en `functions/`, fuente de festivos y caché de la PWA
  tras el despliegue.
- **Calidad de conexión en la subida real** (`image-review-offline-sync`,
  paso 7) — el timeout por registro ya existe (15 s, capa 3); falta decidir
  si además se verifica la conexión antes de subir, y qué pasa si una
  escritura en cola del SDK web llega después del timeout.
- **Qué pasa si le quitan el rol a alguien con registros locales sin
  subir** (`image-review-roles`) — queda como decisión operativa del
  superAdmin, no resuelta por la app.