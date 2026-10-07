---
name: api-resultados-loterias
description: >
  API pública externa https://api-resultadosloterias.com (resultados de
  loterías de Colombia) y la propuesta de lista curada de loterías para el
  campo "lotería" del formulario de revisión de whatsapp_monitor_viewer:
  endpoints con respuestas reales, estructura, rarezas de los datos
  (nombres con codificación dañada, duplicados, variantes FESTIVO, entradas
  "5ta-", filas repetidas), errores, términos y riesgos, la propuesta de
  limpieza y de catálogo en Firestore, la revisión semanal (solo diseño) y
  cómo integrarla respetando las reglas del proyecto. Consulta esta skill
  SIEMPRE que se trabaje en: el campo o selector de lotería del formulario
  (`Comprobante.loteria`), un catálogo de loterías en Firestore, cualquier
  llamada a esa API (app o Cloud Function), o al comparar sus slugs con los
  de `winning_numbers` / `resultados_loterias` / `manual_lotteries` — aunque
  el usuario no nombre la API. Todo lo de abajo distingue VERIFICADO (con
  fecha) de NO VERIFICADO / SUPUESTO; no tomes lo segundo como hecho.
---

# API Resultados Loterías y catálogo de loterías

**Estado: investigación y propuestas. ACTUALIZACIÓN (2026-10-05)**: el usuario
decidió otra vía y se implementó: la lista cerrada de **43 loterías vive como
una constante en la app** (`lib/core/lotteries/lotteries.dart`), con
identificadores que son la clave normalizada de `lotteryKey` de la función
puente (no los slugs de esta API), la lotería es obligatoria por comprobante y
la comparación con los ganadores es por lotería (ver
`image-review-firebase-integration`, "Pieza b3" y "Lotería por comprobante y
comparación por lotería (la app)"). **NO se implementó nada de lo propuesto
aquí**: ni el catálogo en Firestore (§6), ni la revisión semanal (§7), ni
reglas, ni script de carga; la lista curada de §5 (con slugs de esta API) no
es la lista que se usa. Esta skill queda como referencia de la API y de sus
rarezas. Es una API gratuita de un proyecto pequeño: haz solo las llamadas
necesarias, sin ráfagas.

Convención seguida para esta skill: archivo plano `.claude/skills/<nombre>.md`
con frontmatter `name` + `description` (con "Consulta esta skill SIEMPRE
que..."), en español, como las `image-review-*`.

Leyenda: **[V 2026-10-05]** verificado llamando a la API ese día (hora local
Bogotá ~20:13–20:20; el servidor respondía con cabecera `Date` de
2026-10-06 01:13 GMT). **[SUP]** supuesto o no verificado. **[PROPUESTA]**
diseño sin decidir.

---

## 1. Qué es y qué NO dice la documentación

- Proyecto Laravel de un autor individual (Miguel López Ariza / Gotisoft).
  Las 4 páginas de docs (`/docs/1.0/introduction`, `/lotteries`, `/results`,
  `/contribute`) se leyeron completas el 2026-10-05. [V]
- Fuente de los datos según `/contribute`: el paquete `mlopez/supergiros`
  (packagist). La página invita a modificar y aportar **al proyecto**
  (código), no habla de los datos. [V]
- **Las docs NO mencionan**: términos de uso, licencia, permiso o prohibición
  de copiar/almacenar los datos, límites de uso, disponibilidad/SLA, ni
  política de cambios. [V — ausencia en las 4 páginas]
- `robots.txt` existe y no prohíbe nada (`User-agent: *`, `Disallow:` vacío).
  [V] No es una licencia.
- El repo público `gotisoft-com/APIResultadosLoterias` no tiene licencia
  detectada por GitHub (`license: null`), último push 2025-09-13. [V]
  "Sin licencia" no es "permiso": **copiar los datos a nuestra base no está
  expresamente autorizado ni prohibido [V]; sin permiso escrito es un riesgo
  legal que decide el usuario.** Los nombres de loterías (hechos) y una lista
  curada por nosotros pesan mucho menos que replicar resultados.
- Cabeceras de respuesta de `/api/*`: `X-RateLimit-Limit: 60` y
  `X-RateLimit-Remaining` (bajaba de a 1 por llamada), `Access-Control-Allow-Origin: *`.
  [V] **El periodo del límite (por minuto, hora…) NO está documentado**; no
  asumir. Las páginas de docs no traen esas cabeceras.
- Disponibilidad: no hay garantía documentada. Durante la sesión no hubo
  fallos (≈60 llamadas), lo que no prueba nada a futuro. [V/SUP]

## 2. Endpoints (ejemplos reales, 2026-10-05)

Base: `https://api-resultadosloterias.com`. Sin autenticación. Respuesta
siempre JSON `{"status": "...", ...}`.

### GET /api/lotteries
Devuelve **108** entradas, **108 slugs únicos y 108 nombres únicos**, solo
los campos `name` y `slug`. [V]
```json
{"status":"success","data":[{"name":"ANTIOQUEÑITA MAÑANA FESTIVO","slug":"antioquenita-manana-festivo"}, ...]}
```
(La respuesta va con escapes `\uXXXX`; un cliente JSON los decodifica bien.)

### GET /api/results  y  GET /api/results/{yyyy-MM-dd}
`/api/results` sin fecha devolvió la fecha de **hoy en Bogotá**
(2026-10-05) aunque el servidor ya estaba en el 6 en GMT; idéntico byte a
byte a `/api/results/2026-10-05`. [V] (Zona horaria del servidor exacta: SUP.)
```json
{"status":"success","data":[{"lottery":"ANTIOQUEÑITA MAÑANA","slug":"antioquenita-manana","date":"2026-10-05","result":"4171","series":"005"},
 {"lottery":"5ta-ANTIOQUEÑITA MAÑANA","slug":"5ta-antioquenita-manana","date":"2026-10-05","result":"41715","series":"null"}]}
```
Campos: `lottery`, `slug`, `date`, `result` (texto, ceros a la izquierda
conservados), `series` (texto; la cadena literal `"null"` en las "5ta-"). [V]

### Comportamiento observado por caso [V 2026-10-05]
| Llamada | Resultado |
|---|---|
| fecha pasada con datos (`2025-12-24`) | 200, 95 filas |
| fecha de hoy `2026-10-05` a las ~20:13 | 200, 31 filas; 20:20 igual (sin cambios en 7 min) |
| día anterior `2026-10-04` (domingo) | 200, 45 filas |
| fecha sin resultados: `2026-10-06` (mañana), `2026-12-31`, formato `20261005` | **200** con `{"status":"success","data":[]}` — las docs dicen 404, **nunca se vio 404** |
| mal formada `abc`, `2026-13-45` | **500** `{"status":"error","message":"Could not parse 'abc': Failed to parse time string ..."}` (filtra el mensaje interno del parser) |
| laxa: `2026-1-5` | 200 y lo interpreta como 2026-01-05 |
| inexistente: `2026-02-30` | 200 pero **desborda a 2026-03-02**: las filas traen `date: "2026-03-02"` |
| fechas viejas | `2020-01-01`: 8 filas; `2023-02-01`: 27; `2023-12-25`: 6; `2024-12-25`: 21; `2025-06-15`: 64 |

Consecuencias: validar `^\d{4}-\d{2}-\d{2}$` antes de llamar y comprobar que
cada fila trae `date` igual a la pedida.

**A qué hora aparecen los resultados: NO medido** (habría que llamar cada
hora). Solo se vio: el lunes 2026-10-05 a las 20:13–20:20 faltaban
`motilon-noche` y `super-astro-luna` (sorteos de noche) respecto a un día
normal. [V]; horas exactas [SUP/pendiente].

## 3. Rarezas de los datos [V]

1. **Codificación dañada** en 7 de las 108 entradas de `/lotteries`: el
   nombre trae `Ã‘` (UTF-8 leído como cp1252) donde va `Ñ`, y como el slug se
   derivó del nombre dañado **perdió letras** (`antioqueaita-maaana`,
   `caribeaa-dia`, `caribeaa-festivo-dia`, `caribeaa-noche`,
   `antioqueaita-tarde`, `antioqueaita-festiva-maaana`,
   `antioqueaita-festiva-tarde`). Cada una duplica a la correcta (con `Ñ` y
   slug `antioquenita-…`/`caribena-…`). En 44 fechas muestreadas **solo
   `caribeaa-festivo-dia` apareció en resultados, y solo el 2020-01-01**:
   son artefactos históricos. Arreglo seguro de nombre: reinterpretar
   `Ã‘`→`Ñ` (`encode('cp1252').decode('utf-8')`); pero **el slug dañado no se
   puede reconstruir, solo mapear a mano**.
2. **Espacios dobles**: `CAFETERITO NOCHE  FESTIVO`, `LA FANTASTICA NOCHE  FESTIVO`
   (slug limpio: `cafeterito-noche-festivo`, `la-fantastica-noche-festivo`).
3. **`SAMANFESTIVO`** (`samanfestivo`) duplica a `SAMAN FESTIVO` (`saman-festivo`).
   Nunca visto en resultados.
4. **FESTIVO/FESTIVA con el orden cambiado**: p. ej. `caribena-dia-festivo`,
   `caribena-festivo-dia`; `caribena-festiva-noche` vs `caribena-noche-festivo`;
   `paisita-dia-festivo` vs `paisita-festivo-dia`. Se pueden agrupar quitando
   FESTIVO/FESTIVA y comparando las palabras restantes.
5. **El slug no es un id independiente**: sale del nombre, no hay otro
   identificador (solo `name` y `slug`). Por eso un nombre dañado dio un slug
   dañado. Estabilidad en el tiempo: los slugs "limpios" de 2023–2026 son los
   mismos en toda la muestra; no se vio un renombrado, pero **no hay garantía**. [V/SUP]
6. **`/results` trae slugs que `/lotteries` NO lista**: los 53 slugs distintos
   `5ta-*` (sorteos con una quinta cifra: `result` de 5 dígitos, `series`
   `"null"`; p. ej. `5ta-antioquenita-manana` = `41715` junto a
   `antioquenita-manana` = `4171`), más `super-astro-luna`, `super-astro-sol`,
   `chontico-noche-jueves-9` (la lista trae `chontico-noche-jueves`, sin
   `-9`), `loteria-extra-de-cundinamarca` y `loteria-extra-chiquinquira`.
   **`/lotteries` no sirve como lista completa de lo que realmente sortea.**
7. **Filas repetidas**: 346 casos de un mismo slug + fecha repetido en los
   resultados de la muestra (p. ej. `motilon-dia` 2024-12-25: 4 filas
   idénticas `6179`/`000`). Hay que deduplicar al consumir.
8. **Muchas entradas de la lista nunca traen resultados** en 44 fechas
   muestreadas (2020-01-01, 2023-02-01, 2023-12-25, 2024-12-25, 2025-06-15,
   2025-12-24/25/31, 2026-01-01/12, 03-23, 04-02/03, 05-01, 06-29, 07-20,
   08-17, septiembre 3, 5, 6, 10, 12 y 14–30, y octubre 1–5): 35 de 108
   (casi todas los duplicados dañados/FESTIVA y los sorteos extra, más
   `dorado`, `culona`, `culona-festivo`, `motilon`, `motilon-festivo`,
   `pijao-festivo`, `cafeterito-noche-festivo`, `extra-cruz-roja`,
   `chontico-noche-jueves`…). **Muestra parcial: no prueba que nunca salgan**
   (los extras son ocasionales).
9. **Variantes FESTIVO**: en los días festivos y domingos solo aparecen slugs
   `-festivo` (p. ej. 2026-01-01, 2026-01-12, 2026-03-23, domingo 2026-09-06) y
   en días normales solo los no-festivo (2026-09-16); no conviven el mismo día
   en la muestra. Parece el mismo sorteo con otro slug en festivo. **No se
   puede afirmar que sean sorteos distintos o el mismo** → duda D1 abajo.
10. Loterías de un solo día por semana (`cruz-roja` martes, `cundinamarca` y
    `tolima` lunes, `huila` martes: vistas en esos días) → no esperar todas
    las loterías todos los días.
11. Nombres que se escriben a mano en los tickets sí existen en la lista:
    `DORADO TARDE` (`dorado-tarde`, visto 2026-10-05) y `CRUZ ROJA`
    (`cruz-roja`, vista los martes 09-15, 09-22, 09-29). [V]

## 4. Relación con nuestro proyecto [V 2026-10-05, leyendo el código]

- La función puente `syncWinningNumbers` (`functions/index.js`,
  `winningNumbersSync.js`, `winningNumbers.js`) **NO usa esta API**: lee
  Firestore del proyecto `whats-apuestas` (`resultados_loterias/{fecha}`,
  campo `resultados: [{nombreLoteria, slug, numero, serie}]`, y
  `manual_lotteries/{fecha}.list` con `{lottery, slug, date, result, series}`).
  La forma de las entradas manuales es idéntica a la de esta API y la de
  `resultados_loterias` es su traducción al español, pero **quién escribe
  `resultados_loterias` y con qué fuente es SUPUESTO/no verificado**.
- `winning_numbers/{fecha}` solo tiene el campo `numbers` (lista de textos de
  3–4 dígitos). **No guarda lotería ni slug**: no hay relación con los slugs de
  esta API. Además el emparejamiento interno (`lotteryKey` + alias
  `doramana → dorado_manana`) muestra que los slugs del ERP usan otra
  convención (`dorado_mañana` con guion bajo) que esta API (`dorado-manana`).
  **No asumir que los slugs coinciden.**
- `Comprobante.loteria` era texto libre opcional (`String?`) y el lector lo lee
  como `c['loteria'] as String?` (ausente → null, no omite el registro). Desde
  el 2026-10-05 guarda el identificador de la lista cerrada de 43 y es
  obligatoria al guardar; sigue siendo `String?` para leer registros viejos.

## 5. Propuesta de limpieza y lista curada [PROPUESTA — sin decidir]

Reglas, en este orden (aplicables igual en la revisión semanal):
1. Reparar la codificación del nombre (`Ã‘`→`Ñ`); el slug dañado NO se
   repara, se mapea a mano.
2. Quitar espacios sobrantes y pasar a mayúscula inicial.
3. Separar la palabra FESTIVO/FESTIVA, ordenar el resto y volver a poner un
   único sufijo `festivo` (`caribena-noche-festivo`); `samanfestivo` →
   `saman-festivo`.
4. Id canónico = slug del nombre limpio sin tildes (`ñ`→`n`); coincide con el
   slug "bueno" de la API cuando existe.
5. Excluir `5ta-*` (es la quinta cifra del mismo sorteo, no otra lotería) y
   no unir sorteos distintos (`dorado-tarde` ≠ `dorado-noche` ≠ `dorado-manana`).
6. Incluir lo que `/results` trae y `/lotteries` no (marcado "no" abajo).

**Dudas que decide el usuario**
- **D1** FESTIVO/FESTIVA: ¿mismo sorteo con otro slug en festivo (una sola
  entrada en el selector) o sorteo aparte (entradas separadas, a veces
  mostrando solo las del día)? La tabla las deja como entradas separadas por
  no perder información; fusionarlas es trivial después (mapa de slugs).
- **D2** Entradas "históricas" (vistas solo en 2020/2023: `cafeterito-*`,
  `cafetero`, `chontico`, `chontico-festivo`, `dorado-festivo`,
  `la-fantastica-*`, `paisita-festivo`, `ast-lun-2150`, `ast-sol-1350`) y las
  "no vistas": ¿entran activas, entran inactivas o no entran?
- **D3** Sorteos extra (`sorteo-extra-*`, `super-extra-*`, `extra-*`,
  `loteria-extra-*`): ¿se muestran siempre u ocasionales?
- **D4** Nombres con tilde en pantalla (la API no las trae salvo `Ñ`: "Dia",
  "Bogota"); ¿se muestran tal cual o con tildes?

Lista (generada con las reglas sobre la muestra de 44 fechas del 2026-10-05;
94 entradas; el mapa slug → id es la columna "slugs crudos"):

| id propuesto | nombre limpio | slugs crudos que absorbe | en /lotteries | visto en la muestra (44 fechas) |
|---|---|---|---|---|
| `antioquenita-manana` | Antioqueñita Mañana | `antioqueaita-maaana`, `antioquenita-manana` | sí | 26 fechas, última 2026-10-05 |
| `antioquenita-manana-festivo` | Antioqueñita Mañana Festivo | `antioquenita-manana-festivo`, `antioqueaita-festiva-maaana`, `antioquenita-festiva-manana` | sí | 17 fechas, última 2026-10-04 |
| `antioquenita-tarde` | Antioqueñita Tarde | `antioqueaita-tarde`, `antioquenita-tarde` | sí | 26 fechas, última 2026-10-05 |
| `antioquenita-tarde-festivo` | Antioqueñita Tarde Festivo | `antioquenita-tarde-festivo`, `antioqueaita-festiva-tarde`, `antioquenita-festiva-tarde` | sí | 16 fechas, última 2026-10-04 |
| `ast-lun-21-50` | Ast-lun 21:50 | `ast-lun-2150` | sí | 2 fechas, última 2023-02-01 |
| `ast-sol-13-50` | Ast-sol 13:50 | `ast-sol-1350` | sí | 1 fechas, última 2023-02-01 |
| `astro-luna` | Astro Luna | `astro-luna` | sí | 7 fechas, última 2026-01-12 |
| `astro-sol` | Astro Sol | `astro-sol` | sí | 2 fechas, última 2025-12-31 |
| `bogota` | Bogota | `bogota` | sí | 6 fechas, última 2026-10-01 |
| `boyaca` | Boyaca | `boyaca` | sí | 5 fechas, última 2026-10-03 |
| `cafeterito-festivo` | Cafeterito Festivo | `cafeterito-festivo` | sí | 1 fechas, última 2020-01-01 |
| `cafeterito-noche` | Cafeterito Noche | `cafeterito-noche` | sí | 1 fechas, última 2023-02-01 |
| `cafeterito-noche-festivo` | Cafeterito Noche Festivo | `cafeterito-noche-festivo` | sí | no visto |
| `cafetero` | Cafetero | `cafetero` | sí | 1 fechas, última 2023-02-01 |
| `cafetero-dia` | Cafetero Dia | `cafetero-dia` | sí | 25 fechas, última 2026-10-05 |
| `cafetero-noche` | Cafetero Noche | `cafetero-noche` | sí | 24 fechas, última 2026-10-03 |
| `cafetero-noche-festivo` | Cafetero Noche Festivo | `cafetero-noche-festivo` | sí | 16 fechas, última 2026-10-04 |
| `caribena-dia` | Caribeña Dia | `caribeaa-dia`, `caribena-dia` | sí | 26 fechas, última 2026-10-05 |
| `caribena-dia-festivo` | Caribeña Dia Festivo | `caribena-dia-festivo`, `caribeaa-festivo-dia`, `caribena-festivo-dia` | sí | 18 fechas, última 2026-10-04 |
| `caribena-noche` | Caribeña Noche | `caribeaa-noche`, `caribena-noche` | sí | 25 fechas, última 2026-10-03 |
| `caribena-noche-festivo` | Caribeña Noche Festivo | `caribena-festiva-noche`, `caribena-noche-festivo` | sí | 16 fechas, última 2026-10-04 |
| `cauca` | Cauca | `cauca` | sí | 5 fechas, última 2026-10-03 |
| `chontico` | Chontico | `chontico` | sí | 2 fechas, última 2023-02-01 |
| `chontico-dia` | Chontico Dia | `chontico-dia` | sí | 25 fechas, última 2026-10-05 |
| `chontico-dia-festivo` | Chontico Dia Festivo | `chontico-dia-festivo`, `chontico-festivo-dia` | sí | 17 fechas, última 2026-10-04 |
| `chontico-festivo` | Chontico Festivo | `chontico-festivo` | sí | 1 fechas, última 2020-01-01 |
| `chontico-noche` | Chontico Noche | `chontico-noche` | sí | 26 fechas, última 2026-10-05 |
| `chontico-noche-festivo` | Chontico Noche Festivo | `chontico-noche-festivo` | sí | 16 fechas, última 2026-10-04 |
| `chontico-noche-jueves` | Chontico Noche Jueves | `chontico-noche-jueves` | sí | no visto |
| `chontico-noche-jueves-9` | Chontico Noche Jueves 9 | `chontico-noche-jueves-9` | **no** | 5 fechas, última 2026-10-01 |
| `cruz-roja` | Cruz Roja | `cruz-roja` | sí | 3 fechas, última 2026-09-29 |
| `culona` | Culona | `culona` | sí | no visto |
| `culona-dia` | Culona Dia | `culona-dia` | sí | 26 fechas, última 2026-10-05 |
| `culona-dia-festivo` | Culona Dia Festivo | `culona-dia-festivo`, `culona-festivo-dia` | sí | 13 fechas, última 2026-10-04 |
| `culona-festivo` | Culona Festivo | `culona-festivo` | sí | no visto |
| `culona-noche` | Culona Noche | `culona-noche` | sí | 26 fechas, última 2026-10-05 |
| `culona-noche-festivo` | Culona Noche Festivo | `culona-festivo-noche`, `culona-noche-festivo` | sí | 15 fechas, última 2026-10-04 |
| `cundinamarca` | Cundinamarca | `cundinamarca` | sí | 3 fechas, última 2026-09-28 |
| `dorado` | Dorado | `dorado` | sí | no visto |
| `dorado-festivo` | Dorado Festivo | `dorado-festivo` | sí | 1 fechas, última 2020-01-01 |
| `dorado-manana` | Dorado Mañana | `dorado-manana` | sí | 28 fechas, última 2026-10-05 |
| `dorado-noche` | Dorado Noche | `dorado-noche` | sí | 22 fechas, última 2026-10-03 |
| `dorado-noche-festivo` | Dorado Noche Festivo | `dorado-noche-festivo` | sí | 16 fechas, última 2026-10-04 |
| `dorado-tarde` | Dorado Tarde | `dorado-tarde` | sí | 28 fechas, última 2026-10-05 |
| `extra-cruz-roja` | Extra Cruz Roja | `extra-cruz-roja` | sí | no visto |
| `extra-de-colombia` | Extra De Colombia | `extra-de-colombia` | sí | 1 fechas, última 2026-09-30 |
| `fantastica-dia` | Fantastica Dia | `fantastica-dia` | sí | 25 fechas, última 2026-10-05 |
| `fantastica-noche` | Fantastica Noche | `fantastica-noche` | sí | 24 fechas, última 2026-10-03 |
| `fantastica-noche-festivo` | Fantastica Noche Festivo | `fantastica-noche-festivo` | sí | 16 fechas, última 2026-10-04 |
| `huila` | Huila | `huila` | sí | 3 fechas, última 2026-09-29 |
| `la-fantastica-dia` | La Fantastica Dia | `la-fantastica-dia` | sí | 1 fechas, última 2023-02-01 |
| `la-fantastica-festivo` | La Fantastica Festivo | `la-fantastica-festivo` | sí | 1 fechas, última 2020-01-01 |
| `la-fantastica-noche` | La Fantastica Noche | `la-fantastica-noche` | sí | 1 fechas, última 2023-02-01 |
| `la-fantastica-noche-festivo` | La Fantastica Noche Festivo | `la-fantastica-noche-festivo` | sí | no visto |
| `loteria-extra-chiquinquira` | Loteria Extra Chiquinquira | `loteria-extra-chiquinquira` | **no** | 1 fechas, última 2026-09-19 |
| `loteria-extra-de-cundinamarca` | Loteria Extra De Cundinamarca | `loteria-extra-de-cundinamarca` | **no** | 1 fechas, última 2026-09-12 |
| `manizales` | Manizales | `manizales` | sí | 6 fechas, última 2026-09-30 |
| `medellin` | Medellin | `medellin` | sí | 3 fechas, última 2026-10-02 |
| `meta` | Meta | `meta` | sí | 6 fechas, última 2026-09-30 |
| `motilon` | Motilon | `motilon` | sí | no visto |
| `motilon-dia` | Motilon Dia | `motilon-dia` | sí | 43 fechas, última 2026-10-05 |
| `motilon-festivo` | Motilon Festivo | `motilon-festivo` | sí | no visto |
| `motilon-noche` | Motilon Noche | `motilon-noche` | sí | 41 fechas, última 2026-10-04 |
| `paisita-3-sabados` | Paisita 3 Sabados | `paisita-3-sabados` | sí | 5 fechas, última 2026-10-03 |
| `paisita-dia` | Paisita Dia | `paisita-dia` | sí | 26 fechas, última 2026-10-05 |
| `paisita-dia-festivo` | Paisita Dia Festivo | `paisita-dia-festivo`, `paisita-festivo-dia` | sí | 17 fechas, última 2026-10-04 |
| `paisita-festivo` | Paisita Festivo | `paisita-festivo` | sí | 1 fechas, última 2020-01-01 |
| `paisita-noche` | Paisita Noche | `paisita-noche` | sí | 26 fechas, última 2026-10-05 |
| `paisita-noche-festivo` | Paisita Noche Festivo | `paisita-festivo-noche`, `paisita-noche-festivo` | sí | 16 fechas, última 2026-10-04 |
| `pijao` | Pijao | `pijao` | sí | 26 fechas, última 2026-10-05 |
| `pijao-festivo` | Pijao Festivo | `pijao-festivo` | sí | no visto |
| `pijao-noche-festivo` | Pijao Noche Festivo | `pijao-noche-festivo` | sí | 16 fechas, última 2026-10-04 |
| `quindio` | Quindio | `quindio` | sí | 5 fechas, última 2026-10-01 |
| `risaralda` | Risaralda | `risaralda` | sí | 3 fechas, última 2026-10-02 |
| `saman` | Saman | `saman` | sí | 26 fechas, última 2026-10-05 |
| `saman-festivo` | Saman Festivo | `saman-festivo`, `samanfestivo` | sí | 16 fechas, última 2026-10-04 |
| `santander` | Santander | `santander` | sí | 3 fechas, última 2026-10-02 |
| `sinuano-dia` | Sinuano Dia | `sinuano-dia` | sí | 26 fechas, última 2026-10-05 |
| `sinuano-dia-festivo` | Sinuano Dia Festivo | `sinuano-dia-festivo`, `sinuano-festivo-dia` | sí | 16 fechas, última 2026-10-04 |
| `sinuano-noche` | Sinuano Noche | `sinuano-noche` | sí | 25 fechas, última 2026-10-03 |
| `sinuano-noche-festivo` | Sinuano Noche Festivo | `sinuano-festivo-noche`, `sinuano-noche-festivo` | sí | 15 fechas, última 2026-10-04 |
| `sorteo-extra-cauca` | Sorteo Extra Cauca | `sorteo-extra-cauca` | sí | no visto |
| `sorteo-extra-cruzroja-valle` | Sorteo Extra Cruzroja-valle | `sorteo-extra-cruzroja-valle` | sí | no visto |
| `sorteo-extra-de-bogota` | Sorteo Extra De Bogota | `sorteo-extra-de-bogota` | sí | no visto |
| `sorteo-extra-de-boyaca` | Sorteo Extra De Boyaca | `sorteo-extra-de-boyaca` | sí | 1 fechas, última 2025-12-24 |
| `sorteo-extra-de-manizales` | Sorteo Extra De Manizales | `sorteo-extra-de-manizales` | sí | no visto |
| `sorteo-extra-del-tolima` | Sorteo Extra Del Tolima | `sorteo-extra-del-tolima` | sí | 1 fechas, última 2026-09-26 |
| `sorteo-extra-santander` | Sorteo Extra Santander | `sorteo-extra-santander` | sí | no visto |
| `super-astro-luna` | Super Astro Luna | `super-astro-luna` | **no** | 33 fechas, última 2026-10-04 |
| `super-astro-sol` | Super Astro Sol | `super-astro-sol` | **no** | 23 fechas, última 2026-10-05 |
| `super-extra-medellin` | Super Extra Medellin | `super-extra-medellin` | sí | no visto |
| `super-extra-navidad-medellin` | Super Extra Navidad Medellin | `super-extra-navidad-medellin` | sí | no visto |
| `tolima` | Tolima | `tolima` | sí | 3 fechas, última 2026-09-28 |
| `valle` | Valle | `valle` | sí | 6 fechas, última 2026-09-30 |

## 6. Catálogo en Firestore [PROPUESTA — sin construir]

- Colección PROVISIONAL `catalogo_loterias`, **un documento** `actual` con
  todo el catálogo (unas 94 entradas ≈ 10–15 KB, muy bajo el límite de 1 MiB
  por documento). Abrir el selector = **1 lectura** (y 1 por sesión si se
  guarda en memoria, como `jornadas`).
- Estructura recomendada: **mapa por id**, no lista, para poder agregar o
  desactivar una entrada con una escritura puntual sin leer-modificar-escribir:
  ```
  catalogo_loterias/actual {
    version: 1,
    items: { "dorado-tarde": { nombre: "Dorado Tarde", festivo: false,
                               activa: true, slugs: ["dorado-tarde"] }, ... }
  }
  ```
- Los registros guardan el **id** (`loteriaId`) y el nombre limpio del momento
  (`loteria`), así un registro se entiende aunque el catálogo cambie.
  Nunca se borra una entrada: se pone `activa: false`.
- Regla (solo propuesta; NO está en `firestore.rules.draft`): lectura para
  cualquier usuario con sesión, sin escritura, como `jornadas`.
- Carga única con Admin SDK, como `festivos_colombia` (lista generada con
  reglas, revisada por el usuario, `set` completo, verificada releyendo; la
  copia local vive fuera del repo): script local con modo de prueba que solo
  imprime el documento, revisión del usuario, `set`, relectura y comparación.
  Sin nada automático.

## 7. Revisión semanal [PROPUESTA — solo diseño]

Cada 7 días: 1 llamada a `/api/lotteries` y, para ver lo que `/lotteries` no
lista, `/api/results/{fecha}` de los últimos 7 días (8 llamadas por semana en
total, espaciadas ≥2 s). Aplica las mismas reglas de la sección 5 y compara
contra el catálogo:
- **Nueva** = slug sin id en el mapa de slugs → aviso.
- **Desaparecida** = todos los slugs de una entrada con `activa: true` y que
  estaban en `/lotteries` ya no están → aviso (se marcaría inactiva a mano;
  las entradas que solo vienen de `/results`, como `super-astro-luna`, no se
  juzgan por ausencia: los sorteos ocasionales no aparecen todas las semanas).
- Nunca modifica ni borra el catálogo. Deja el aviso en un documento aparte
  (`catalogo_loterias_avisos/ultimo`, solo lectura de admin) y un
  `logger.warn` en Cloud Logging.
- Anfitrión posible sin crear otro proceso: la función horaria
  `syncWinningNumbers` (ya hospeda las jornadas en su propio try/catch).
  Se ejecutaría solo si es lunes y la hora de Bogotá es la elegida (ninguna
  lectura extra); si esa corrida falla se pierde la semana, salvo que se añada
  un documento de estado (1 lectura por corrida). Alternativa: una función
  programada propia (un job más de Cloud Scheduler). Requiere salida a
  internet desde Functions; no necesita secreto (la API no tiene llave).
- Costo: 8 llamadas/semana a la API, 1 lectura del catálogo y 1 escritura por
  semana, segundos de ejecución dentro de una función que ya corre cada hora.
- Agregar una lotería nueva a mano mientras tanto: en la consola de Firestore
  agregar un campo al mapa `items` (nombre, festivo, activa, slugs), o un
  script de una línea con `update({"items.<id>": {...}})` que no toca el resto.

## 8. Compatibilidad con el campo obligatorio [PROPUESTA]

- El lector de subidos omite documentos ilegibles
  (`firestore_review_remote_records_datasource.dart`) y `fromMap` falla si falta
  un campo requerido; hoy `loteria` ausente da `null` y NO omite el registro.
- Lo más simple: **no endurecer la lectura**. La obligatoriedad vive solo en la
  validación del formulario al guardar (`validateImageReviewForm`), como
  `codigo`. Los registros viejos (pendientes en Hive o ya subidos) sin
  `loteriaId` se siguen leyendo y subiendo; al reabrirlos se pide completarlo al
  guardar. Resumen y Coincidencias tratan `null` como "sin lotería".
- Alternativa más estricta (como se hizo con `codigo`: los pendientes sin él no
  se suben hasta guardarlos de nuevo): bloquea subidas viejas; no recomendada
  salvo que se necesite el dato en todos los registros.
- Valor ya guardado en `loteria` (texto libre) no se migra: queda como nombre
  histórico con `loteriaId: null`.

## 9. Errores y qué hacer

| Situación | Qué hacer |
|---|---|
| 200 con `data: []` | "Sin resultados" (no es error): no escribir nada |
| 500 / `status: "error"` | Fallo: registrar solo el tipo y la fecha pedida, no reintentar en ráfaga, dejar el catálogo intacto |
| Timeout o sin red | Igual; la revisión espera a la siguiente semana |
| 404 | Documentado, nunca observado: tratarlo como "sin datos" |
| Fecha de fila ≠ fecha pedida | Descartar (desbordes tipo `2026-02-30`) |
| Slug desconocido | Aviso, no añadir solo |

## 10. Integración respetando las reglas del proyecto

- **La app no llama a la API** (decidido) y menos mientras se llena un
  formulario. La app solo lee `catalogo_loterias/actual` de Firestore.
- Lectura en la app: datasource nuevo `.get()` con `Either<Failure, T>`, sin
  lanzar excepciones hacia arriba; ante fallo, el selector no bloquea el
  trabajo ya guardado (mismo patrón que `shift_schedule`).
- Revisión semanal en Node (`functions/`): `fetch` con tiempo límite, validar
  `status === "success"` y la forma antes de usar, capturar todo en try/catch
  propio (un fallo no debe tirar el resto del handler) y no registrar
  contenido de respuestas. Probar con dependencias inyectadas como
  `winningNumbersSync.js`.
- Riesgos: términos sin definir (sección 1), disponibilidad sin garantía,
  slugs derivados del nombre (un renombrado cambia el slug), fuente
  `mlopez/supergiros` fuera de nuestro control.

## 11. Sin confirmar (no actuar sobre ello)

- (Resuelto el 2026-10-05 por el usuario: la lotería va **por comprobante**, la
  eligen **los dos roles** y se muestran las **43** de la constante de la app;
  las dudas D1–D3 de la sección 5 quedaron sin efecto para esa lista.)
