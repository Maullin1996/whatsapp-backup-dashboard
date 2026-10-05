# Pruebas de reglas de Firestore (emulador local)

Prueba el archivo **completo** `../firestore.rules.draft` (el mismo que se
pega a mano en la consola) contra el emulador local de Firestore. Usa el
proyecto `demo-review-rules`: nunca toca `whatsapp-pro-3d483` ni publica nada.

## Requisitos

- Node.js y Firebase CLI (`firebase --version`).
- **Java 21 o superior** (el emulador de Firebase CLI 15 no arranca con
  Java 17). Si el Java del sistema es más viejo, basta con un JDK 21
  portátil y apuntar `JAVA_HOME` y `PATH` a él solo para esta corrida.

## Correr

Desde esta carpeta:

```powershell
npm install
# Solo si el Java del sistema es < 21:
$env:JAVA_HOME = "C:\ruta\al\jdk-21"; $env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm test
```

Imprime una línea por caso (`OK` / `FALLA`, esperado y obtenido) y el total.
Termina con código 1 si algún caso no sale como se esperaba. Las líneas
`PERMISSION_DENIED` del SDK en las escrituras negadas son normales.

Para probar otra copia de las reglas (por ejemplo lo que hay en la
consola): `$env:RULES_PATH = "C:\ruta\a\otras.rules"` antes de `npm test`.

## Qué no cubre

No usa cuentas ni tokens reales (los claims se simulan), no comprueba
índices de Firestore y no reemplaza el simulador de la consola.
