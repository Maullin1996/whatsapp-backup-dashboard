---
name: image-review-domain
description: >
  Vocabulario y reglas de negocio del sistema de revisión de imágenes de
  whatsapp_monitor_viewer (comprobantes, números, totales, roles Revisor y
  Sumador, reconciliación, jornadas). Consulta esta skill SIEMPRE que se
  trabaje en cualquier parte del feature de revisión de imágenes: el
  formulario en image_detail_page, el modelo de datos de comprobantes,
  la pantalla de resumen por jornada/grupo, la validación de que revisor
  y sumador cuadren, o cualquier entidad/repository/notifier relacionado
  — aunque el mensaje del usuario no use las palabras "dominio" o "reglas
  de negocio". Es la fuente de verdad del modelo: si el código o una
  conversación previa contradice esta skill, gana esta skill salvo que
  el usuario indique explícitamente que la regla cambió (y en ese caso,
  actualízala aquí también).
---

# Dominio: Revisión de imágenes (comprobantes "Bono Paga Diario")

Esta skill NO tiene instrucciones de implementación (arquitectura, Firebase,
cache, UI). Solo fija el **vocabulario y las reglas de negocio**. Las demás
skills del feature (`image-review-roles`, `image-review-offline-sync`,
`image-review-firebase-integration`, `image-review-workflow`) asumen que
lo de aquí ya se entendió correctamente.

## Por qué existe esta skill

El feature se construye en varias sesiones/chats distintos (a veces meses
aparte). Sin este documento, es fácil reinventar mal el modelo de datos
cada vez. Antes de tocar código de este feature, lee esta skill completa.

## Vocabulario

- **Imagen**: la foto que ya existe en el chat (`whatsapp_messages` +
  `storagePath`). No es nueva — es la imagen que ya se ve en
  `ImageDetailPage`.
- **Comprobante** ("Bono Paga Diario" en la foto física): unidad dentro de
  una imagen. **Una imagen puede tener 1 o varios comprobantes** (en el
  ejemplo real que definió esta skill, una imagen traía 4 comprobantes).
  Cada comprobante tiene su propio código impreso (`COD`). El código es
  **texto libre** (dígitos como "0123", o el nombre de una región) y es
  **obligatorio**: se le aplica `trim` y es error solo si queda vacío;
  no se valida el formato ni se normalizan mayúsculas o tildes. **Lo
  anotan ambos roles, Revisor y Sumador, cada uno por su cuenta** (igual
  que el total). **El código
  identifica a la persona que registró el ticket, no al ticket en sí** —
  por eso el mismo código puede repetirse en varios comprobantes (de la
  misma imagen o de imágenes distintas). **Nunca se suman entre sí dos
  comprobantes solo por compartir código** — cada ticket es una unidad
  independiente aunque el código coincida.
- **Número**: cada entrada escrita a mano dentro de un comprobante (en el
  ejemplo, cosas como `5311`, `1111`, `2023`...). Un comprobante tiene
  **N números** (cantidad variable, no fija). **Solo los anota el
  Revisor; el Sumador no anota números.**
- **Total del comprobante**: el valor final escrito en el comprobante
  (en el ejemplo, `$9000`, `$3000`). Lo anotan **ambos roles, Revisor y
  Sumador, de forma independiente** (ver regla 2 y 3 — es una doble
  verificación, no dos datos distintos).
- **Valores sueltos**: los montos individuales que se ven junto a cada
  número dentro del ticket (ej. "500"). Son visibles en la foto pero
  **la app no los pide como dato de entrada**: sumados entre sí no dan
  el total del comprobante, así que no sirven para calcular ni validar
  nada — son ruido visual del papel, no un dato del formulario.
- **Jornada**: turno laboral (mañana, tarde 1, tarde 2, noche 1, noche 2,
  domingo/festivo, fuera de jornada — ver `lib/core/time/shifts.dart`
  en el repo). Todo el feature de revisión se agrupa por jornada.
- **Números ganadores**: lista externa (hoy local/mock, más adelante vía
  Cloud Function) contra la que se comparan los números registrados por
  el Revisor, para detectar coincidencias.

## Estructura de datos (conceptual, no es el modelo Dart final)

```
Imagen (1)
 └── Comprobantes (1..N)
      ├── código — OBLIGATORIO, texto libre, anotado por Revisor y por
      │    Sumador (identifica a quien registró el ticket; se puede
      │    repetir, nunca implica que dos comprobantes se sumen)
      ├── Números (1..N) — SOLO Revisor (el valor del número en sí, para
      │    poder cruzarlos contra números ganadores)
      └── Total del comprobante
           ├── anotado por el Revisor
           └── anotado por el Sumador (independiente, para verificación)

Registro de imagen (lo que se guarda por imagen Y POR ROL, ver
image-review-roles: cada imagen tiene DOS registros independientes, uno del
Revisor y otro del Sumador, con clave (messageId, rol); guardar uno nunca
toca al otro y ninguno lee al otro)
 ├── rol = Revisor o Sumador (`ReviewRole`): con qué rol se diligenció
 ├── jornada (derivada de la hora del mensaje, no elegida a mano)
 ├── fecha del registro = fecha en que se leyó/registró la imagen
 │    (NO la fecha de captura del mensaje en WhatsApp — ver nota abajo)
 ├── registrado por = correo del usuario (Revisor o Sumador) que lo
 │    diligenció (ver image-review-roles, auditoría por correo)
 ├── editado = booleano, true si se corrigió después de guardado/subido
 │    (ver image-review-offline-sync, reusa el patrón de isEdited)
 ├── anotaciones (texto libre, OPCIONAL — para reportar que algo no
 │    cuadra, un número ilegible, etc.)
 └── datos internos de navegación (id de imagen/chat/grupo — ver
      image-review-roles, punto de redirección)
```

**Nota sobre la fecha**: el formulario NO reutiliza la fecha del mensaje
de WhatsApp como si fuera la fecha del registro — la fecha "que ya se
tiene por defecto cuando se lee la imagen" se refiere al momento en que
el Revisor/Sumador abre y diligencia el formulario, no a la metadata
original del mensaje. Si esto se malinterpretó, confirmar con el usuario
antes de implementar.

## El modelo `Message` existente y qué se puede derivar de él

Este es el modelo real del repo (`lib/features/messages/domain/`, ya
existente — no crear uno nuevo, reutilizar este):

```dart
class Message {
  final String id;
  final String chatJid;
  final String senderName;
  final String? caption;
  final String? storagePath;
  final bool hasMedia;
  final int messageTimestamp;
  final String localTime;
  final String shift;
  final String messageDate;
  final bool isEdited;
  final int? shiftImageIndex;

  bool get isImage => hasMedia && storagePath != null;
}
```

Consecuencias para el feature de revisión:

- **Solo se puede registrar un `Message` si `isImage == true`** (tiene
  `storagePath`). Un mensaje de puro texto nunca entra al flujo de
  Revisor/Sumador.
- **La redirección desde la pantalla de resumen (coincidencia con número
  ganador) no necesita "navegar" a `image_detail_page` para mostrar
  contexto** — con `id`, `chatJid`, `senderName`, `storagePath`, `shift`,
  `localTime` e `isEdited` ya alcanza para construir una vista/tarjeta de
  contexto (a qué grupo pertenece, cuándo se registró, quién lo envió).
  La imagen en sí (pedir la URL con `storagePath` vía
  `imageUrlProvider`) solo se carga **si el usuario hace click** para
  ver la imagen completa — no se precarga por defecto solo por aparecer
  en el resumen. Esto es una decisión de rendimiento, no una regla de
  negocio dura; si en la práctica conviene precargar, se puede ajustar.
- **`shiftImageIndex` como conteo de avance de la jornada — HIPÓTESIS
  DESCARTADA como mecanismo de cierre**: se pensó inicialmente en usar
  el valor más alto de `shiftImageIndex` como "total esperado" para
  saber cuándo una jornada está completa. **El usuario confirmó que
  esto no es confiable**: el Revisor puede estar diligenciando el
  formulario mientras siguen llegando imágenes nuevas a esa misma
  jornada, así que "el total esperado" puede seguir creciendo mientras
  se trabaja — no hay un momento fijo en el que `shiftImageIndex` deje
  de moverse. **Ver la sección "Cierre de jornada: decisión de diseño"
  más abajo para el mecanismo que reemplaza esta idea.**
  `shiftImageIndex` sigue siendo útil como **dato informativo** (ej.
  mostrar "llevas N registros" mientras se trabaja), pero nunca como
  condición dura para habilitar el botón de subida.

## Cierre de jornada: decisión de diseño (reemplaza la hipótesis de `shiftImageIndex`)

Dado que no existe un conteo confiable de "cuántas imágenes va a tener
esta jornada en total" (ver arriba), y dado que **cada jornada+grupo
tiene asignado un único Revisor y un único Sumador** (ver
`image-review-roles`, ahora regla confirmada de asignación), la
recomendación de diseño es:

- **No intentar detectar automáticamente "jornada completa" contando
  imágenes.** En su lugar, el indicador/botón de subida de una jornada
  (`image-review-offline-sync`) se muestra **tan pronto exista al menos
  un registro local pendiente** en esa jornada — la decisión de "ya
  terminé, no van a llegar más imágenes" queda en manos de la persona
  que está trabajando esa jornada (es la única con esa asignación, así
  que es quien mejor sabe si ya se acabaron los envíos).
- **La validación real de "está completo y correcto" no depende de
  contar imágenes, sino de la reconciliación (regla 3 más abajo)**: se
  suman todos los totales que anotó el Revisor en la jornada y se
  comparan contra la suma de todos los totales que anotó el Sumador en
  esa misma jornada. Si coinciden, todo bien. Si no coinciden —ya sea
  porque a alguno le faltó registrar un comprobante, o porque alguien
  se equivocó anotando un total— **sale la alerta en la pantalla de
  resumen**. Esa alerta ES el mecanismo real de detectar que algo quedó
  incompleto o mal, no un conteo previo de imágenes esperadas.
- **La subida de una jornada no tiene que ser única/definitiva**: si
  después de subir llegan imágenes nuevas a esa misma jornada (poco
  probable dado que ya pasó su ventana horaria, pero posible por
  mensajes que llegan tarde), la persona puede seguir registrando y
  volver a presionar "subir" — no diseñar esto como un candado de
  "una sola subida por jornada para siempre".

## Reglas de negocio (no negociables sin confirmación explícita del usuario)

1. **Cardinalidad libre**: una imagen puede tener 1 comprobante o varios;
   un comprobante puede tener 1 número o varios. Nunca asumir cantidad
   fija ni deshabilitar "agregar otro" después de cierto número.
2. **Doble verificación por captura independiente, no por cálculo**:
   Revisor y Sumador anotan **los mismos datos — el código y el total de
   cada comprobante — cada uno por su cuenta**, sin ver lo que anotó el
   otro. **Solo el Revisor anota los números.** No es que uno calcule y
   el otro registre partes; ambos ven la misma foto y ambos escriben el
   código y el total que leen. El propósito es detectar errores de
   transcripción de uno de los dos (por eso el Sumador existe: para
   comprobar que el Revisor anotó bien, y viceversa).
   *(Nota: este punto se corrigió — el modelo anterior de "el Sumador
   anota valores sueltos por número" quedó descartado porque esos
   valores sueltos, sumados, nunca coinciden con el total real del
   comprobante.)*
3. **Reconciliación — CONFIRMADA, es agregada por jornada, no por
   comprobante**: se suman **todos** los totales anotados por el
   Revisor en la jornada, y por separado **todos** los totales anotados
   por el Sumador en esa misma jornada. Las dos sumas deben ser
   iguales. **No se empareja comprobante por comprobante** — no hace
   falta saber cuál total del Revisor corresponde a cuál total del
   Sumador, solo que las dos sumas totales de la jornada coincidan. Si
   no coinciden, **no se bloquea el registro** — se muestra una alerta,
   pero **en la pantalla de resumen**, no en `image_detail_page`. Esta
   comparación agregada es también el mecanismo real para detectar que
   a alguien le faltó registrar algo (ver "Cierre de jornada" arriba).
4. **Agrupación por jornada, nunca combinado ni siquiera dentro del
   mismo día**: todo total, suma y alerta de descuadre se agrupa y se
   muestra **por jornada** (mañana, tarde 1, tarde 2, etc.). El usuario
   confirmó explícitamente que esto **nunca** se combina en un total
   del día — ni siquiera como una vista agregada adicional. Un día con
   4 jornadas se ve y se reporta como 4 unidades independientes, nunca
   como una quinta cifra "total del día".
5. **Los reportes son diarios y no acumulables**: el resumen por
   jornada/grupo de un día **nunca se suma con el de otro día**. Cada
   día es una unidad de reporte independiente. Si se necesita histórico,
   es una vista de "varios reportes diarios lado a lado", nunca una
   suma acumulada.
6. **Anotaciones son siempre opcionales, para los dos roles, y son el
   ÚNICO campo opcional del formulario** (texto libre; vacías o solo
   espacios se normalizan a `null`). No tienen estructura ni afectan la
   reconciliación numérica; sirven para que un humano revise después
   ("este número no se ve bien", "esta suma no me da"). Todo lo demás es
   obligatorio, y varía por rol:
   - **Revisor**: al menos un comprobante; y por comprobante, código
     (texto libre, `trim`, no vacío), al menos un número (String, con
     `trim`, conservando ceros a la izquierda) y total entero > 0.
   - **Sumador**: al menos un comprobante; y por comprobante, código
     (mismas reglas) y total entero > 0. **Sin números.**

   `validateImageReviewForm(form, rol)` (fail-fast; orden: comprobantes,
   código, números —solo Revisor—, total) aplica las reglas del rol. Para
   el Sumador la lista de números se normaliza siempre a vacía (lo que
   llegue se descarta).
7. **Coincidencia con números ganadores**: se busca solo contra los
   **números** que registró el Revisor, porque el Sumador no anota
   números. Si un número coincide con un número ganador, debe
   quedar visible (en la pantalla que corresponda, ver
   `image-review-firebase-integration`) el número, el grupo al que
   pertenece, y debe permitir navegar de vuelta a esa imagen exacta.

## Zona gris / a confirmar con el usuario antes de implementar

- Si Revisor y Sumador ven **la misma foto** para anotar el total cada
  uno por su lado, ¿lo hacen en momentos distintos o son dos
  formularios simultáneos en la misma sesión? Esto probablemente ya no
  aplica igual ahora que se confirmó que cada jornada+grupo tiene un
  único Revisor y un único Sumador asignados (`image-review-roles`) —
  cada uno trabaja con su propia cuenta, así que "simultáneo" solo
  significaría "los dos conectados al mismo tiempo cada uno en su
  sesión", no dos personas compartiendo una sola sesión.