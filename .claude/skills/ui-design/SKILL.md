---
name: ui-design
description: Guía de diseño UI de whatsapp_monitor_viewer. Úsala SIEMPRE que se cree o modifique una página, diálogo, bottom sheet, widget visual, lista, skeleton de carga o cualquier pantalla de la app (login, home/chats, mensajes, visor de imágenes, admin), aunque el usuario no diga "UI" ni "diseño". Define paleta, espaciados, bordes, patrón responsive mobile/desktop, estados de carga/vacío/error y textos en español para mantener consistencia visual.
---

# UI Design — whatsapp_monitor_viewer

App Flutter (web PWA + móvil) con estética **limpia estilo WhatsApp Web**: fondos claros, verde como acento, tarjetas blancas con bordes suaves. Toda la UI está en español.

Antes de escribir UI, lee un widget vecino de la misma feature para calzar con su estilo. Esta skill resume las convenciones reales del código; si algo aquí contradice el código actual, manda el código y actualiza esta skill.

## Principios

1. **Reutiliza antes de crear**: `ResponsiveLayout`, `AppBreakpoints`, `AppShimmer`, `CustomTextFormField` (en `lib/core/`) y el sistema de theming (`lib/core/theme/`, ver abajo). Si un estilo se repite 3+ veces, extráelo a `lib/core/` en vez de copiarlo.
2. **Sí hay `ThemeData` global**: `MaterialApp.router(theme: AppTheme.light)` en `lib/app/app.dart` (`lib/core/theme/app_theme.dart`). Fija los defaults de `ElevatedButton`, `TextButton`, `OutlinedButton`, `FloatingActionButton`, `Card`, `Dialog`, `BottomSheet`, `PopupMenu`, `InputDecoration`, `Switch`, `Checkbox`, `Radio`, `Divider`, `Chip`, `SnackBar`, `Tooltip` y `AppBar`. **Antes de pasarle `style`/`shape`/`decoration` a mano a uno de estos widgets, comprueba si el valor que ibas a poner ya es el default del tema** (verde `AppColors.primaryGreen`, radio `AppRadius.button`/`AppRadius.dialog`/`AppRadius.card`, blanco, etc.) — si coincide, no lo repitas, solo el widget sin `style` ya sale correcto. Sobreescribe puntualmente solo para casos especiales (botón rojo "Eliminar", botón naranja/morado de rol, etc.), pasando únicamente las propiedades que cambian. Usa `Theme.of(context).textTheme` para tipografía base.
3. **Todo texto visible en español** (tooltips, labels, snackbars, vacíos, errores). Los mensajes de error vienen de `mapFailureToMessage` / `failure.message`, no los inventes en la UI.
4. **Mobile y desktop son ambos ciudadanos de primera**: la app se usa como PWA en escritorio y en móvil.

## Sistema de theming (`lib/core/theme/`)

Importa todo con un solo barrel: `import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';`

| Archivo | Qué define |
|---|---|
| `app_theme.dart` (`AppTheme.light`) | El `ThemeData` global — ver Principio 2. No forma parte del barrel `theme.dart` (solo se usa una vez, en `app.dart`); impórtalo aparte si necesitas leerlo. |
| `app_colors.dart` (`AppColors`) | Paleta (ver tabla abajo). |
| `app_spacing.dart` (`AppSpacing`) | Escala de espaciado: `xs=4, sm=8, md=12, lg=16, xl=24`. |
| `app_radius.dart` (`AppRadius`) | Radios con nombre semántico (`thumbnail=6, button=8, tile=10, card=12, skeletonCard=14, dialog=16, search=18, pill=20`), más `...All` ya como `BorderRadius` (`AppRadius.buttonAll`, etc.). |
| `app_shadows.dart` (`AppShadows`) | `AppShadows.bubble` (sutil) y `AppShadows.loginCard` (la única sombra pronunciada de la app). |
| `app_sizes.dart` (`AppSizes`) | Anchos máximos (`loginFormMaxWidth`, `adminPanelMaxWidth`, `messageBubbleMaxWidth`, `emptyStateMaxWidth`), `chatAvatarRadius`, `AppSizes.chatListWidth(screenWidth)`, `AppSizes.reviewPanelWidth(screenWidth)` (panel del formulario del visor: 34 % del ancho, entre 360 y 440). |
| `app_durations.dart` (`AppDurations`) | Duraciones de animación de UI con nombre semántico (`hover`, `quick`, `pageTransition`, `chatItemAppear`, `messageItemAppear`, `stateSwitch`, `scrollToLatest`, `shimmer`). No uses esto para timers de lógica de negocio (debounce/batching de notifiers): esos se quedan como `Duration` literal en el notifier. |
| `app_typography.dart` (`AppTypography`) | Estilos con nombre para patrones repetidos: `senderName(context)`, `timestamp(context)`, `headerTitle(context)`, `adminAppBarTitle`, `badge`, `chatTileTitle`, `avatarInitials`, `tabular` (cifras de ancho fijo para códigos/números que se comparan a simple vista; se combina con `copyWith`). |

Regla general: **si vas a escribir un número mágico de espaciado/radio/duración/ancho máximo, primero mira si ya existe un token que lo cubra.** Si el valor no calza con ningún token (p. ej. un `6` o `20` puntual que no se repite), un literal está bien — no fuerces un token a un valor distinto solo por parecerse.

## Paleta

Definida en `lib/core/theme/app_colors.dart` (`AppColors`). Úsala en vez de literales cuando exista el color:

| Token | Uso |
|---|---|
| `AppColors.primaryGreen` | Acento principal: FAB, switches, avatares activos, botones primarios (ya es el default de `ElevatedButtonTheme`/`FloatingActionButtonTheme`) |
| `AppColors.loadingColor` (`Colors.green`) | Spinners / indicadores de carga |
| `AppColors.errorMessage` (`Colors.red`) | Errores, acciones destructivas |
| `AppColors.upLoginBackground` → `downLoginBackground` | Gradiente del login (topLeft→bottomRight) |
| `AppColors.inputBackground` | Relleno de inputs (default de `InputDecorationTheme`) |
| `AppColors.inputBorder` | Borde verde claro de inputs (2 px) |
| `AppColors.screenBackground` | Fondo beige gris de pantallas (`scaffoldBackgroundColor` del tema); paneles de lista van en `Colors.white` |
| `AppColors.accentTeal` | Teal de filtros/acento secundario (badge de filtro activo, iconos activos) |
| `AppColors.roleAdmin` / `AppColors.roleSuperAdmin` | Colores de rol (naranja / morado) |
| `AppColors.success` | Éxito (`Colors.green`) |
| `AppColors.warning` | Advertencia / pendiente (ámbar oscuro, p. ej. chip "Sin guardar" del panel del Revisor). No uses `roleAdmin` para esto: tiene otro significado |
| `AppColors.divider` | Divisores/bordes suaves (`black alpha 0.12`) |
| `AppColors.activeTile` | Fondo de tile activo/seleccionado en listas |

Colores usados en el código sin token (mantenlos consistentes; si los reusas 3+ veces, promuévelos a `AppColors`):
- Nombre del remitente: `Colors.teal`.
- Avatares de chat: paleta `_avatarColors` en `chat_list.dart` indexada por `groupName.hashCode`; el texto sobre el avatar se elige claro/oscuro según luminancia (`_isLight`).

Reglas: usa `withValues(alpha: …)` (no `withOpacity`, está deprecado). Nunca hardcodees un color nuevo si uno de arriba sirve.

## Espaciado, formas y elevación

- Espaciado: usa `AppSpacing` (`xs/sm/md/lg/xl` = 4/8/12/16/24) en vez de números sueltos. Padding horizontal de pantalla móvil: `AppSpacing.lg`; de tarjetas/listas: `AppSpacing.sm`–`AppSpacing.md`.
- Radios: usa `AppRadius` — inputs/diálogos `dialog` (16), tarjetas/tiles `card`/`tile` (10–12), botones/burbujas `button` (8), buscador `search` (18), chips/badges/bottom sheets `pill` (20).
- Elevación mínima: la app usa bordes finos (`Border.all(color: grey.shade300)`, `BorderSide` inferior en headers) y sombras muy sutiles (`AppShadows.bubble`, blur 0.5). Las sombras grandes solo en la tarjeta de login (`AppShadows.loginCard`). Evita `elevation` fuerte de Material (el tema ya pone `elevation: 0` en `Card`/`AppBar`).
- Anchos máximos de contenido en desktop: usa `AppSizes` (`loginFormMaxWidth`, `adminPanelMaxWidth`, `messageBubbleMaxWidth`, `emptyStateMaxWidth`). Centra con `Center` + `ConstrainedBox(maxWidth)`.
- Lista de chats en desktop: `AppSizes.chatListWidth(screenWidth)`.

## Tipografía

Usa `Theme.of(context).textTheme` y ajusta con `copyWith`, o los estilos con nombre de `AppTypography` cuando el patrón ya está cubierto:
- Títulos de header → `AppTypography.headerTitle(context)`.
- Nombre de remitente → `AppTypography.senderName(context)`. Hora/fecha → `AppTypography.timestamp(context)`.
- Títulos de AppBar de admin → `AppTypography.adminAppBarTitle` (o simplemente deja el `AppBar` sin `titleTextStyle`: el tema ya pone 20, bold, verde — solo usa el token si necesitas un tamaño puntual distinto).
- Badges → `AppTypography.badge`. Nombre de chat en tile → `AppTypography.chatTileTitle`. Iniciales de avatar → `AppTypography.avatarInitials`.
- Texto largo en una línea: `maxLines: 1` + `overflow: TextOverflow.ellipsis`. En web, texto que el usuario pueda querer copiar (nombre de grupo, remitente) va en `SelectableText` (`kIsWeb`).

## Responsive (obligatorio en páginas y diálogos)

- Breakpoints en `lib/core/responsive/breakpoints.dart` (`AppBreakpoints`): `mobile` = **600** (uso general), `homeSplit` = **700** (umbral del layout dividido lista|conversación de `HomePage`, más ancho porque ahí conviven dos paneles) y `reviewForm` = **840** (a partir de aquí el visor de imágenes muestra el panel del formulario del Revisor junto a la imagen; es la clase de ventana "expanded" de Material 3 — entre 600 y 840 hay tablets verticales y celulares horizontales. **Adoptado, pendiente de validar en dispositivos reales**: tablet vertical/horizontal y laptop). No hardcodees otro número; si necesitas un nuevo umbral con su propia razón de ser, añádelo aquí con un comentario, como `homeSplit`.
- Patrón estándar para una página/diálogo con layouts distintos:

```dart
class MiPage extends ConsumerWidget {
  const MiPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveLayout(
      mobile: _MiPageMobile(/* estado y callbacks */),
      desktop: _MiPageDesktop(/* estado y callbacks */),
    );
  }
}
```

  Cada variante es un widget privado `_XxxMobile` / `_XxxDesktop` en el mismo archivo; el padre posee el estado (controllers, providers, `ref.listen`) y les pasa datos + callbacks. Si mobile y desktop solo difieren en medidas, usa un solo widget con `MediaQuery.sizeOf(context).width < AppBreakpoints.mobile` (como `MessageBubble`).
- Para dimensionar según el espacio disponible (no el de pantalla) usa `LayoutBuilder`.
- Móvil: `SafeArea`, `SingleChildScrollView` con `keyboardDismissBehavior: onDrag` en formularios, navegación por pantalla completa (lista → conversación con `AnimatedSwitcher` 220 ms y botón "Volver"). Desktop: panel dividido (lista | contenido) con `VerticalDivider(width: 1)`.
- Prueba mentalmente ambos anchos (p. ej. 360 y 1280) y con teclado abierto; evita `RenderFlex overflow` usando `Expanded`/`Flexible`/`SingleChildScrollView`.

## Estados de pantalla (siempre los tres)

Toda vista con datos asíncronos cubre **carga, vacío y error**:
- **Carga**: skeleton con `AppShimmer` (base `grey.shade300`, highlight `grey.shade100`, 1200 ms) que imita la forma final (ver `chats_loading_view.dart`, `message_bubble_skeleton.dart`, `loading_widget.dart`). Spinner `CircularProgressIndicator` solo para acciones puntuales / imágenes.
- **Vacío**: texto centrado en español ("No hay usuarios registrados") o el panel `CustomMessageGroup` en home.
- **Error**: mensaje en español desde el `Failure`; para acciones, `SnackBar` (verde éxito / rojo error) disparado desde `ref.listen` y luego `clearMessages()`. Imágenes fallidas: icono `broken_image` + "Toca para reintentar".
- Transiciones entre estados: `AnimatedSwitcher` (~400 ms, `easeOutCubic`/`easeInCubic`, `FadeTransition`) con `KeyedSubtree(key: ValueKey('loading'|'empty'|'data'))`.

## Componentes y patrones existentes

- **Inputs**: `CustomTextFormField` (relleno `inputBackground`, borde verde claro `AppColors.inputBorder` de 2 px, radio 16, label flotante negro) — esto también es el default de `InputDecorationTheme`, así que un `TextFormField` suelto sin `decoration` ya sale igual. Úsalo para formularios en vez de repetir la decoración. Buscadores: `filled`, `grey.shade200`, radio 18 (caso especial, no usa el input theme).
- **Diálogos**: `showDialog` con `AlertDialog`/`Dialog` — el tema ya los pone blancos con radio 16 (`DialogThemeData`), **no repitas `backgroundColor: Colors.white` ni `shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogAll)`**. Botón cancelar en verde (texto, ya es el default de `TextButtonTheme`); acción principal `ElevatedButton` — si es la acción normal (verde), no le pases `style`; si es destructiva o de rol, pásale solo `ElevatedButton.styleFrom(backgroundColor: ..., foregroundColor: Colors.white)` (el radio de botón ya sale del tema, no lo repitas). Acciones destructivas siempre piden confirmación. Diálogos con `ResponsiveLayout` (mobile casi pantalla completa, desktop ancho acotado).
- **Bottom sheets**: `showModalBottomSheet` (filtro de fechas), solo para móvil/acciones rápidas. El tema ya pone fondo blanco y esquinas superiores con radio `pill` (`BottomSheetThemeData`).
- **Headers de conversación**: `Container` blanco + borde inferior `black alpha 0.12–0.2`, padding `h16 v12` (desktop) / `h8 v10` (móvil), botón con `tooltip` en español.
- **Tiles de lista** (`ChatList`): `MouseRegion` con hover `grey alpha 0.15`, activo `Color.fromARGB(159,236,234,234)`, radio 12, avatar circular de radio 27.5.
- **Badges/chips**: fondo color al 12 % de alpha, texto del mismo color, radio 20, w600 tamaño 12.
- **FAB / AppBar (admin)**: AppBar blanco con flecha `arrow_back_ios_new_rounded`; FAB `primaryGreen` con icono `_rounded`. Iconos: preferir variantes `_rounded`.
- **Imágenes**: `ExtendedImage.network` con `cache: true`, `cacheWidth/Height`, `RepaintBoundary`, `ClipRRect` radio 6, `loadStateChanged` con placeholder `Colors.black12`. La URL sale de `imageUrlProvider(storagePath)`, nunca guardes URLs completas.

## Rendimiento (ChatList y MessageList fueron optimizados a propósito)

- Constructores `const` siempre que se pueda; widgets pequeños y granulares en vez de `build` gigantes.
- `ref.watch(provider.select(...))` para reconstruir solo lo necesario; no hagas `watch` de estados grandes en la raíz de listas.
- Listas: `ListView.builder` / `separated`; nada de `Column` con cientos de hijos. Envuelve ítems costosos (imágenes) en `RepaintBoundary`. No calcules cosas caras en `build` (mueve a `initState`/`late final`, como el color del avatar).
- Animaciones cortas (200–400 ms) y sin reconstruir la lista completa.

## Accesibilidad y web

- `tooltip` en todo `IconButton`; áreas táctiles ≥ 40 px; contraste legible sobre fondos claros (texto negro/gris oscuro, evita gris muy claro para info importante).
- Web: soportar mouse (hover, cursor), `SelectableText` para datos copiables, y scroll con mouse/trackpad (ya habilitado en `app.dart`).
- Si añades assets a la PWA, actualiza `pubspec.yaml` y `urlsToCache`/`CACHE_NAME` en `web/sw.js`.

## Estructura al crear una página nueva

1. Ubicación: `lib/features/<feature>/presentation/pages/<nombre>_page.dart`; widgets en `.../widgets/`; providers/notifiers en `.../providers/` o `.../controllers/`.
2. Registra la ruta en `lib/app/router.dart` (GoRouter) respetando los guards de auth/admin.
3. Página = `ConsumerWidget` que observa el provider, escucha efectos (`ref.listen`) y delega a `ResponsiveLayout`.
4. Implementa los 3 estados (carga/vacío/error) y ambos layouts.
5. Añade un widget test en `test/widget/` para lógica visual relevante (ver `message_bubble_test.dart`); envuelve en `ProviderScope`/`MaterialApp` y usa `test_asset_bundle.dart` si carga assets.
6. Verifica: `flutter analyze`, `flutter test`, y revisa visualmente a ~360 px y ~1280 px (hot reload si hay app corriendo).

## Checklist antes de dar por terminado

- [ ] Textos en español; sin strings de error inventados
- [ ] Colores desde `AppColors` o la paleta documentada; `withValues(alpha:)`
- [ ] Espaciado/radios/duraciones/anchos desde `AppSpacing`/`AppRadius`/`AppDurations`/`AppSizes` (sin números mágicos que ya tengan token)
- [ ] No repetido en `Dialog`/`ElevatedButton`/`Card`/etc. lo que ya pone `AppTheme.light` por defecto
- [ ] `ResponsiveLayout` / `AppBreakpoints` (sin números mágicos de breakpoint)
- [ ] Estados carga (shimmer) / vacío / error cubiertos
- [ ] `const` y `ListView.builder`; sin trabajo pesado en `build`
- [ ] Tooltips en iconos, `SafeArea`, sin overflow con teclado
- [ ] Acciones destructivas con confirmación
- [ ] `flutter analyze` limpio
