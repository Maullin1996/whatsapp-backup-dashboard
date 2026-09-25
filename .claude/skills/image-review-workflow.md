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
3. **Persistencia local** (`image-review-offline-sync`): mover el
   guardado del formulario a SQLite/Hive real, probando que sobrevive
   un reload antes de seguir. Como ya no hay que "detectar jornada
   completa" (se descartó, ver `image-review-domain`), este paso es más
   simple de lo que se pensaba originalmente: solo guardar y listar
   pendientes.
4. **Indicador/botón de subida por jornada** (`image-review-offline-sync`):
   aparece con el primer registro pendiente, sin lógica de conteo — la
   persona asignada decide cuándo presionarlo.
5. **Pantalla de resumen por jornada/grupo** (`image-review-domain` +
   `image-review-roles`): reconciliación agregada (suma de totales del
   Revisor vs. suma de totales del Sumador, por jornada), alertas de
   descuadre, sin acumular entre días ni entre jornadas del mismo día.
   Esta pantalla es también el mecanismo real de detectar que algo
   quedó incompleto o mal — no un conteo previo.
6. **Integración Firebase con mocks** (`image-review-firebase-integration`):
   Cloud Function puente simulada, jornadas y números ganadores locales
   — para poder construir y probar la pantalla nueva de coincidencias
   sin depender del proyecto externo real. El enum `Shift` local se
   mantiene tal cual hasta el siguiente paso.
7. **Conexión real a Firebase** (`image-review-firebase-integration`):
   una vez el usuario tenga acceso al proyecto externo, revisar el
   formato real de jornadas/números ganadores y reemplazar los mocks
   del paso 6 — varios puntos de esta skill quedaron explícitamente
   diferidos hasta ese momento (ver Pendientes globales).

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
- **Tres puntos diferidos explícitamente hasta tener acceso al proyecto
  externo de Firebase** (`image-review-firebase-integration`): mecanismo
  de recepción de números ganadores (webhook vs. polling), formato real
  de las jornadas por fecha, y el contrato completo de la Cloud
  Function puente. El usuario dijo que los revisamos juntos cuando
  tenga acceso a ese proyecto — no intentar adivinarlos antes.
- **Qué pasa si le quitan el rol a alguien con registros locales sin
  subir** (`image-review-roles`) — queda como decisión operativa del
  superAdmin, no resuelta por la app.