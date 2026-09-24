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
  mobile), y la validación de que no se puede avanzar de imagen sin
  completar el formulario. Consulta esta skill SIEMPRE que se trabaje
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
  ya es `superAdmin`**, y **nunca aplica sobre otro `superAdmin`**.
- Todas las mutaciones de `AdminNotifier` son optimistas (actualizan el
  estado local antes de llamar la Cloud Function, revierten si falla).

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
2. **Activación exclusiva desde `AdminPage`, exclusiva del superAdmin**:
   igual que "Hacer admin/Quitar admin", los switches/botones para
   `revisor` y `sumador` en `_UserCard` solo son visibles/interactuables
   si `AuthenticatedUser.isSuperAdmin == true` para quien está mirando
   el panel. Un `admin` normal (no super) no puede activarlos ni verlos
   activables.
3. **Nunca se activan desde el cliente sin pasar por Cloud Function**:
   se necesita una Cloud Function nueva (o extender `setUserRole` para
   aceptar el nombre del rol como parámetro) — seguir el patrón exacto
   de `setUserRole`, incluyendo la actualización optimista en
   `AdminNotifier` y el revert si falla. La Cloud Function es también
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
- Implementación: reusar `AppBreakpoints` como base (ver `ui-design`
  SKILL.md del proyecto), pero **el usuario ya confirmó que el umbral
  actual (`mobile = 600`) probablemente no alcanza** para distinguir
  "mobile real" de "tablet" — lo más probable es que haga falta agregar
  un umbral nuevo a `AppBreakpoints` (con su comentario documentando
  la razón, igual que `homeSplit`), específico para decidir si se
  muestra el formulario de captura. El valor exacto (¿768? ¿840?) se
  define al implementar, probando con dispositivos/anchos reales.
- Un usuario con rol Revisor o Sumador que entra desde un celular debe
  poder seguir viendo las imágenes normalmente; solo no ve el
  formulario de captura ahí.

## Validación: no se puede avanzar de imagen sin completar el formulario

- Si el usuario activo tiene rol Revisor o Sumador **y** está en una
  pantalla donde el formulario aplica (tablet/PC), **no puede pasar a
  la siguiente imagen del visor sin completar el formulario de la
  imagen actual**.
- "Completar" significa, como mínimo, los campos obligatorios definidos
  en `image-review-domain`. Para el **Revisor**: al menos un
  comprobante, y cada comprobante con código, al menos un número y
  total > 0 (regla implementada en `validateImageReviewForm`). Para el
  **Sumador**: al menos un comprobante, y cada comprobante con código y
  total > 0, sin números (regla confirmada; falta implementarla en
  código, hoy `validateImageReviewForm` solo cubre al Revisor). Las
  anotaciones nunca son obligatorias, son siempre opcionales.
- Esta validación es **de navegación dentro del visor**, no de guardado:
  no impide cerrar la app o salir de `image_detail_page` por completo,
  solo bloquea el gesto/flecha/botón de "imagen siguiente" mientras
  falte el formulario de la imagen actual.
- Un usuario que **no** tiene rol Revisor ni Sumador (ej. un usuario
  normal, o un `admin`/`superAdmin` sin esos roles activados) navega el
  visor exactamente igual que hoy, **sin ningún formulario, ni siquiera
  en modo lectura** — simplemente ve la imagen. El formulario de captura
  solo existe para quien tiene activa la cualidad Revisor o Sumador.
- **Edición de un registro ya diligenciado**: si Revisor/Sumador
  navega (buscando manualmente, sin atajo — ver `image-review-offline-sync`)
  hasta una imagen que **ya tiene un registro guardado** (local o ya
  subido), `image_detail_page` debe mostrar un **botón "Editar"** en
  vez de un formulario vacío. La validación de "no avanzar sin
  completar" (arriba) no aplica sobre una imagen que ya tiene registro
  — esa restricción es solo para imágenes sin diligenciar todavía.

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

## Asignación de grupo + jornada — CONFIRMADA (ya no es "futuro")

El usuario confirmó explícitamente esto: **cada Revisor y cada Sumador
tiene asignado un grupo específico y una jornada específica** a
revisar — el rol no aplica de forma genérica a todos los
grupos/jornadas. Además:

- **Unicidad**: dos personas con el mismo rol (dos Revisores, o dos
  Sumadores) **nunca pueden tener asignados el mismo grupo y la misma
  jornada a la vez**. Un Revisor y un Sumador **sí** pueden (de hecho,
  deben) compartir grupo+jornada — son ellos dos quienes se
  verifican mutuamente sobre esa misma combinación.
- **Implicaciones en el modelo**: `AuthenticatedUser` no puede
  quedarse solo con los booleanos `isRevisor`/`isSumador` (regla 4 de
  la sección anterior) — necesita además el **grupo y la jornada
  asignados**. Esto probablemente no cabe en un custom claim booleano
  simple; lo más natural es un custom claim más rico (objeto, no
  booleano) o un documento en Firestore (`users/{uid}` ya tiene
  `allowedGroups[]` — podría extenderse con algo como
  `revisorAssignment: {grupo, jornada}` / `sumadorAssignment: {grupo,
  jornada}`, a definir en implementación).
- **Cloud Function de asignación**: la Cloud Function que active
  `revisor`/`sumador` (regla 3 de la sección anterior) también necesita
  recibir grupo + jornada, y **validar la unicidad** (rechazar si ya
  existe otro usuario con el mismo rol + mismo grupo + misma jornada)
  antes de guardar.
- **Filtrado de qué ve cada uno**: un Revisor/Sumador probablemente solo
  debería ver/trabajar en el grupo y jornada que tiene asignados —
  parecido al filtrado por `allowedGroups` que ya existe para usuarios
  normales (`ChatsFirestoreDatasource`), pero acotado además por
  jornada dentro del chat. El detalle exacto de cómo se refleja esto en
  `HomePage`/`ChatList`/`image_detail_page` queda para cuando se
  implemente esta pieza (ver `image-review-workflow`).
- **Por qué esto refuerza el diseño de cierre de jornada**
  (`image-review-domain`, sección "Cierre de jornada"): como cada
  jornada+grupo tiene un único responsable por rol, no hay ambigüedad
  sobre quién decide "ya terminé de registrar" — es literalmente la
  única persona con esa asignación.

## Zona gris / a confirmar antes de implementar

- **Valor exacto del breakpoint nuevo** para distinguir tablet/PC de
  celular real (el enfoque ya está confirmado — hace falta uno nuevo —
  falta solo el número, ver sección de dispositivo arriba).