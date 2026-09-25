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
   mecanismo tipo **SQLite (`sqflite`/`drift`) o `Hive`** — el usuario
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

## ⚠️ Antes de implementar: elegir entre SQLite y Hive contra el código real

El usuario ya acotó las opciones a **SQLite (`sqflite`/`drift`) o
Hive** — no hace falta evaluar otras alternativas. **Ya se confirmó
que hoy no existe ninguna capa de persistencia estructurada en el
proyecto** — lo único que hay es el cache de imágenes de
`extended_image` (cachea la imagen en sí, no datos estructurados) y la
persistencia de sesión de Firebase Auth (`FirebaseAuth.instance.setPersistence(Persistence.LOCAL)`
en `main.dart`, que es solo para la sesión de login, no sirve para
guardar formularios). Se empieza de cero — la decisión entre las dos
opciones es libre, a definir en Claude Code según lo que resulte más
cómodo de integrar con Riverpod/Clean Architecture del proyecto:

1. Elegir entre `sqflite`/`drift` y `Hive` pensando en el volumen
   (~200 registros por jornada, consultas por jornada/grupo/rol para
   listar pendientes) — y en cualquier caso, envolverlo en un nuevo
   `LocalDatasource` en la capa `data/` del feature, devolviendo
   `Either<Failure, T>` igual que los demás datasources (ver
   `PROJECT_DOCUMENTATION.md`, sección Manejo de errores) — nunca la
   librería de storage llamada directo desde un Notifier.
2. Actualizar esta skill con la decisión tomada, para que quede
   documentada y no se repita la pregunta en la próxima sesión.

## Forma de trabajo dentro de esta skill

Siguiendo la convención del proyecto ("nunca tirar todo de un solo
golpe"), esta parte del feature se implementa por capas, probando cada
una antes de seguir:

1. **Guardado local de un solo registro** (una imagen, un formulario) —
   probar que sobrevive un reload de página antes de seguir.
2. **Listado de pendientes por jornada** — cuántos registros locales
   hay sin subir para una jornada dada (esto ya no requiere "detectar
   si está completa", solo listar lo que hay).
3. **Subida individual** de un registro pendiente a Firestore.
4. **Subida por jornada** ("subir esta jornada") con manejo de
   éxitos/fallos parciales (regla 4 de la sección anterior).
5. **UI del indicador/botón por jornada** en el listado de mensajes,
   arriba de `GoToLatestMessageButton` — esto va al final, cuando ya se
   probó que el guardado y la subida funcionan por separado.

## Zona gris / a confirmar antes de implementar

- **`sqflite`/`drift` vs. `Hive`**: cuál de las dos — decisión libre, a
  tomar en Claude Code (ver sección de arriba).