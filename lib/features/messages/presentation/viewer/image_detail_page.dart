import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_shift.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/image_review_target.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/providers/image_review_providers.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/widgets/image_review_panel.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/guarded_action.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_controler_actions.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/nav_button.dart';

/// Escala mínima/máxima permitida al hacer zoom en el visor.
const double _minZoomScale = 1.0;
const double _maxZoomScale = 6.0;

/// Escala a la que salta el doble-tap/doble-click cuando la imagen está a
/// escala 1.0 (un segundo doble tap vuelve a 1.0).
const double _doubleTapZoomScale = 2.5;

/// Mensaje cuando se intenta navegar sin haber guardado el formulario.
const String _blockedAdvanceMessage = 'Guarda el formulario para continuar';

/// Tiempo mínimo entre avisos al intentar avanzar con swipe (el bloqueo se
/// dispara en cada movimiento del dedo).
const Duration _blockedNoticeThrottle = Duration(milliseconds: 1500);

/// `item` pertenece a un (chatJid, shift) presente en `shifts`. La jornada de
/// `item` viene como etiqueta en español (`ImageViewItem.shift`); se traduce
/// al enum antes de comparar contra `reviewShifts` (que guarda el nombre del
/// enum). Sin coincidencia de etiqueta (`shiftFromLabel` da `null`) tampoco
/// matchea nada, que es lo seguro. Fuera de jornada (también un hueco entre
/// jornadas, "Fuera de jornada X") nunca hay formulario, aunque alguien
/// hubiera guardado `outOfShift` en `reviewShifts`.
bool _matchesAssignment(List<ReviewShift> shifts, ImageViewItem item) {
  final shift = shiftFromLabel(item.shift);
  if (shift == null || shift == Shift.outOfShift) return false;
  return shifts.any((s) => s.chatJid == item.chatJid && s.shift == shift);
}

/// Busca el item de [id] en [items]; `null` si ya no está en la lista.
ImageViewItem? _itemById(List<ImageViewItem> items, String id) {
  for (final item in items) {
    if (item.messageId == id) return item;
  }
  return null;
}

class ImageDetailPage extends ConsumerStatefulWidget {
  final int initialIndex;

  /// De dónde salen las imágenes. `null` (por defecto): las del chat activo
  /// (`chatImageItemsProvider`, índice 0 = la más nueva).
  final ProviderListenable<List<ImageViewItem>>? items;

  /// `true` (por defecto, el chat): el índice 0 se dibuja a la DERECHA, así
  /// que la flecha derecha va hacia el índice 0 (la más nueva). `false`: el
  /// índice 0 a la IZQUIERDA y la flecha derecha avanza en el índice (de la
  /// primera a la última).
  final bool reverse;

  /// Pide la página siguiente del chat (`messagesProvider.loadMore`) al
  /// acercarse al final de la lista. Solo tiene sentido con las imágenes del
  /// chat.
  final bool paginate;

  /// Si se muestra el botón de cerrar (y Esc cierra). Sin él, el visor no se
  /// cierra desde aquí.
  final bool showClose;

  /// `false`: el botón de cerrar se ve pero deshabilitado (y Esc no cierra).
  /// Solo tiene efecto con [showClose].
  final bool closeEnabled;

  /// Qué hace cerrar. `null` (por defecto): `Navigator.pop`.
  final VoidCallback? onClose;

  /// Con texto, el botón de cerrar es un botón con ese texto en vez del icono.
  final String? closeLabel;

  /// Botones extra en la barra superior, antes del de cerrar.
  final List<Widget> actions;

  /// Formulario de revisión: solo la pantalla de llenado `/review` lo pide
  /// (`true`). Con `false` (por defecto, el visor del chat) el visor es solo
  /// visor, como antes del formulario: sin panel, sin bloqueo de navegación y
  /// sin el foco extra; ni siquiera lee el rol, `reviewShifts` o los
  /// registros guardados. Con `true` el panel sigue sus condiciones de
  /// siempre (ancho, rol y asignación).
  final bool reviewForm;

  const ImageDetailPage({
    super.key,
    required this.initialIndex,
    this.items,
    this.reverse = true,
    this.paginate = true,
    this.showClose = true,
    this.closeEnabled = true,
    this.onClose,
    this.closeLabel,
    this.actions = const [],
    this.reviewForm = false,
  });

  @override
  ConsumerState<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends ConsumerState<ImageDetailPage>
    with SingleTickerProviderStateMixin {
  late final ExtendedPageController _controller;

  /// Posición actual dentro de la lista de imágenes ([_itemsSource]). Se
  /// mantiene sincronizada con [_anchorId]: cuando la lista cambia por tiempo
  /// real el índice puede cambiar, pero la imagen no.
  late int _index;

  /// messageId de la imagen que se está viendo. El visor se ancla a ella y no
  /// al índice, que se corre cuando la lista cambia por tiempo real.
  String? _anchorId;

  /// true mientras el visor reposiciona el pager por un cambio de la lista
  /// (no es navegación del usuario: no dispara loadMore, foco ni avisos).
  bool _anchoring = false;

  /// Una `GlobalKey` de estado de gesto por imagen (por messageId, no por
  /// posición), para que el zoom de una imagen sea independiente del resto y
  /// se quede con ella aunque su posición cambie.
  final Map<String, GlobalKey<ExtendedImageGestureState>> _gestureKeys = {};

  late final AnimationController _zoomAnimationController;
  Animation<double>? _zoomAnimation;
  VoidCallback? _zoomAnimationListener;

  /// Foco del visor: los atajos viven en su `FocusableActionDetector`.
  /// Con el panel del formulario visible hay que devolvérselo después de
  /// escribir en un campo, si no las flechas dejan de funcionar.
  final FocusNode _viewerFocus = FocusNode(debugLabel: 'imageViewer');

  DateTime? _lastBlockedNotice;

  /// messageId de la imagen sobre la que empezó el gesto actual. El bloqueo
  /// del swipe se decide con ella y no con la imagen "actual": `_index` cambia
  /// a mitad del arrastre (al cruzar el 50 %) y no debe congelar un gesto que
  /// empezó desde una imagen ya registrada.
  String? _dragOriginId;

  ProviderListenable<List<ImageViewItem>> get _itemsSource =>
      widget.items ?? chatImageItemsProvider;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = ExtendedPageController(initialPage: _index);
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: AppDurations.quick,
    );
    final items = ref.read(_itemsSource);
    if (items.isNotEmpty) _resolveIndex(items);
    // El listener corre antes del rebuild: el pager se reposiciona antes de
    // que se dibuje una imagen distinta a la que el usuario está viendo.
    ref.listenManual(_itemsSource, (_, items) {
      _onItemsChanged(items);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _zoomAnimationController.dispose();
    _viewerFocus.dispose();
    super.dispose();
  }

  GlobalKey<ExtendedImageGestureState> _gestureKeyFor(String messageId) {
    return _gestureKeys.putIfAbsent(
      messageId,
      () => GlobalKey<ExtendedImageGestureState>(),
    );
  }

  ExtendedImageGestureState? get _currentGestureState {
    final anchor = _anchorId;
    return anchor == null ? null : _gestureKeys[anchor]?.currentState;
  }

  /// Índice de la imagen anclada en [items]. Si esa imagen ya no está (caso
  /// raro: cambio de filtro o de chat con el visor abierto) se queda en la
  /// misma posición, acotada a la lista, y se reancla ahí. [items] no debe
  /// estar vacía.
  int _resolveIndex(List<ImageViewItem> items) {
    final anchor = _anchorId;
    if (anchor != null) {
      final index = items.indexWhere((item) => item.messageId == anchor);
      if (index >= 0) return index;
    }
    final index = _index.clamp(0, items.length - 1);
    _anchorId = items[index].messageId;
    return index;
  }

  void _onItemsChanged(List<ImageViewItem> items) {
    if (items.isEmpty || !mounted) return;
    final ids = {for (final item in items) item.messageId};
    _gestureKeys.removeWhere((id, _) => !ids.contains(id));

    final target = _resolveIndex(items);
    if (target == _index) return;
    // Primero el índice: así el onPageChanged que provoca el salto se ignora.
    _index = target;
    _jumpPagerTo(target);
    setState(() {});
  }

  /// Salto programático (sin animación) del pager. No es bloqueado por
  /// `canScrollPage` (solo filtra el drag del usuario) ni cuenta como
  /// navegación del usuario.
  void _jumpPagerTo(int page) {
    if (!_controller.hasClients || !_controller.position.haveDimensions) return;
    if (_controller.page?.round() == page) return;
    _anchoring = true;
    try {
      _controller.jumpToPage(page);
    } finally {
      _anchoring = false;
    }
  }

  /// El panel del formulario (y el bloqueo de navegación) solo existen con
  /// [ImageDetailPage.reviewForm], en pantallas anchas, con rol activo, y
  /// cuando [item] pertenece a un
  /// (chatJid, shift) que ese rol tiene en `reviewShiftsProvider`. Mientras
  /// esa lectura esté cargando o falle se trata como "sin asignación" (sin
  /// panel), para no mostrar el formulario y ocultarlo después al llegar el
  /// dato. `null` (sin item resuelto, p. ej. lista vacía) tampoco tiene panel.
  bool _showReviewPanelFor(ImageViewItem? item) {
    if (!widget.reviewForm || item == null) return false;
    if (MediaQuery.sizeOf(context).width < AppBreakpoints.reviewForm) {
      return false;
    }
    final rol = ref.read(currentReviewRoleProvider);
    if (rol == null) return false;
    final shifts = ref
        .read(reviewShiftsProvider)
        .maybeWhen(data: (list) => list, orElse: () => const <ReviewShift>[]);
    return _matchesAssignment(shifts, item);
  }

  /// Con el panel visible, la navegación entre imágenes (teclas, chevrons y
  /// swipe, en AMBOS sentidos) se bloquea mientras la imagen actual no tenga
  /// un registro guardado: el Revisor puede empezar desde cualquier imagen,
  /// así que no hay una dirección de avance confiable. Con registro la
  /// navegación es libre (también editando con cambios sin guardar) y cerrar
  /// el visor siempre está permitido. Es una guía de flujo, no un candado: lo
  /// que detecta los faltantes es la reconciliación del resumen.
  ///
  /// [originId]: imagen sobre la que se evalúa (por defecto, la actual).
  bool _isNavigationBlocked({String? originId}) {
    if (!mounted) return false;
    final items = ref.read(_itemsSource);
    if (items.isEmpty) return false;
    final id = originId ?? items[_index.clamp(0, items.length - 1)].messageId;
    final item = _itemById(items, id);
    if (!_showReviewPanelFor(item)) return false;
    final rol = ref.read(currentReviewRoleProvider);
    // Sin rol la navegación es libre.
    if (rol == null) return false;
    return !ref.read(canAdvanceProvider((messageId: id, rol: rol)));
  }

  void _showBlockedNotice() {
    final messenger = ScaffoldMessenger.of(context);
    // El aviso solo existe con el panel visible: se deja libre el ancho del
    // panel para no tapar su botón "Guardar" (que es lo que hay que pulsar).
    final panelWidth = AppSizes.reviewPanelWidth(
      MediaQuery.sizeOf(context).width,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text(_blockedAdvanceMessage),
          margin: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            panelWidth + AppSpacing.lg,
            AppSpacing.lg,
          ),
        ),
      );
  }

  void _noticeBlockedSwipe() {
    final now = DateTime.now();
    final last = _lastBlockedNotice;
    if (last != null && now.difference(last) < _blockedNoticeThrottle) return;
    _lastBlockedNotice = now;
    // Se llama durante el scroll: el aviso se muestra al terminar el frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showBlockedNotice();
    });
  }

  void _onPageChanged(int index) {
    // Los saltos del ancla no son navegación del usuario.
    if (_anchoring || index == _index) return;
    setState(() => _index = index);
    final items = ref.read(_itemsSource);
    final newItem = index < items.length ? items[index] : null;
    if (newItem != null) _anchorId = newItem.messageId;
    // Si el campo enfocado era de la imagen anterior, su foco se perdió.
    if (_showReviewPanelFor(newItem)) _viewerFocus.requestFocus();
    if (widget.paginate && index >= items.length - 3) {
      ref.read(messagesProvider.notifier).loadMore();
    }
  }

  /// Solo deja que el pager cambie de página cuando la imagen actual está a
  /// escala 1.0 y la navegación no está bloqueada. Mientras haya zoom,
  /// desplazarse hacia un lateral mueve la imagen (pan) en vez de cambiar a
  /// la foto siguiente/anterior.
  ///
  /// El paquete consulta esto en cada movimiento del drag y al soltarlo; con
  /// `false` el drag no mueve el pager. No afecta a `jumpToPage`.
  bool _canScrollPage(GestureDetails? details) {
    if ((details?.totalScale ?? 1.0) > 1.0) return false;
    if (_isNavigationBlocked(originId: _dragOriginId)) {
      _noticeBlockedSwipe();
      return false;
    }
    return true;
  }

  /// Hay imagen a la derecha / a la izquierda de la actual (ver
  /// [ImageDetailPage.reverse]).
  bool _canGoRight(int length) =>
      widget.reverse ? _index > 0 : _index < length - 1;
  bool _canGoLeft(int length) =>
      widget.reverse ? _index < length - 1 : _index > 0;

  /// Pasa a la imagen de la derecha / de la izquierda (sin mirar el bloqueo).
  void _goRight() => widget.reverse ? _previousPage() : _nextPage();
  void _goLeft() => widget.reverse ? _nextPage() : _previousPage();

  void _nextPage() =>
      _controller.nextPage(duration: AppDurations.quick, curve: Curves.easeOut);
  void _previousPage() => _controller.previousPage(
    duration: AppDurations.quick,
    curve: Curves.easeOut,
  );

  void _close() {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
    } else {
      Navigator.pop(context);
    }
  }

  void _handleDoubleTap(ExtendedImageGestureState state) {
    final position = state.pointerDownPosition;
    final begin = state.gestureDetails?.totalScale ?? 1.0;
    final end = begin > 1.05 ? 1.0 : _doubleTapZoomScale;
    _animateScaleTo(state, begin: begin, end: end, focalPoint: position);
  }

  void _zoomIn() => _adjustZoom(1.25);
  void _zoomOut() => _adjustZoom(0.8);

  void _adjustZoom(double factor) {
    final state = _currentGestureState;
    final box = state?.context.findRenderObject() as RenderBox?;
    if (state == null || box == null) return;

    final current = state.gestureDetails?.totalScale ?? 1.0;
    final target = (current * factor).clamp(_minZoomScale, _maxZoomScale);
    final center = box.localToGlobal(box.size.center(Offset.zero));
    _animateScaleTo(state, begin: current, end: target, focalPoint: center);
  }

  void _resetZoom() => _currentGestureState?.reset();

  void _animateScaleTo(
    ExtendedImageGestureState state, {
    required double begin,
    required double end,
    Offset? focalPoint,
  }) {
    if (_zoomAnimationListener != null) {
      _zoomAnimation?.removeListener(_zoomAnimationListener!);
    }
    _zoomAnimationController
      ..stop()
      ..reset();

    _zoomAnimationListener = () {
      state.handleDoubleTap(
        scale: _zoomAnimation!.value,
        doubleTapPosition: focalPoint,
      );
    };
    _zoomAnimation = _zoomAnimationController.drive(
      Tween<double>(begin: begin, end: end),
    );
    _zoomAnimation!.addListener(_zoomAnimationListener!);
    _zoomAnimationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(_itemsSource);
    if (items.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    // Red de seguridad: si la lista cambió y el listener aún no reposicionó
    // el pager, el índice se deriva del ancla (el panel nunca se equivoca de
    // imagen) y el pager se corrige al terminar el frame.
    final resolved = _resolveIndex(items);
    if (resolved != _index) {
      _index = resolved;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpPagerTo(_index);
      });
    }
    final safeIndex = _index;
    final item = items[safeIndex];

    final width = MediaQuery.sizeOf(context).width;
    // El registro y el bloqueo son del rol activo: lo guardado por el otro rol
    // no cuenta. Sin formulario (el visor del chat) o sin rol no hay panel, ni
    // clave, ni bloqueo, y no se lee nada del feature de revisión.
    final rol = widget.reviewForm ? ref.watch(currentReviewRoleProvider) : null;
    // "Cargando" o error se tratan igual que "sin asignación": nada de
    // mostrar el panel y ocultarlo después al resolver reviewShiftsProvider.
    final hasAssignment =
        rol != null &&
        ref
            .watch(reviewShiftsProvider)
            .maybeWhen(
              data: (shifts) => _matchesAssignment(shifts, item),
              orElse: () => false,
            );
    final showPanel =
        width >= AppBreakpoints.reviewForm && rol != null && hasAssignment;
    final reviewKey = rol == null
        ? null
        : (messageId: item.messageId, rol: rol);
    final navigationBlocked =
        reviewKey != null &&
        showPanel &&
        !ref.watch(canAdvanceProvider(reviewKey));

    // Tras guardar (o re-guardar) el foco vuelve al visor.
    if (reviewKey != null) {
      ref.listen(savedRecordProvider(reviewKey), (previous, next) {
        if (showPanel && next.value != null && next.value != previous?.value) {
          _viewerFocus.requestFocus();
        }
      });
    }

    final viewer = Column(
      children: [
        _ViwerTopBar(
          shift: item.shift,
          name: item.senderName,
          localTime: item.localTime,
          isEdited: item.isEdited,
          shiftImageIndex: item.shiftImageIndex,
          zoomOut: _zoomOut,
          zoomIn: _zoomIn,
          zoomRest: _resetZoom,
          close: widget.showClose ? _close : null,
          closeLabel: widget.closeLabel,
          closeEnabled: widget.closeEnabled,
          actions: widget.actions,
        ),
        Expanded(
          child: _ImagePager(
            reverse: widget.reverse,
            canGoLeft: _canGoLeft(items.length),
            canGoRight: _canGoRight(items.length),
            goLeft: _goLeft,
            goRight: _goRight,
            controller: _controller,
            items: items,
            gestureKeyFor: _gestureKeyFor,
            onDoubleTap: _handleDoubleTap,
            canScrollPage: _canScrollPage,
            onPageChanged: _onPageChanged,
            navigationBlocked: navigationBlocked,
            onBlockedTap: _showBlockedNotice,
            onPointerDown: showPanel
                ? (_) {
                    _dragOriginId = item.messageId;
                    if (isTextFieldFocused()) _viewerFocus.requestFocus();
                  }
                : null,
          ),
        ),
        _ImageIndexIndicator(index: _index, total: items.length),
      ],
    );

    return FocusableActionDetector(
      autofocus: true,
      focusNode: _viewerFocus,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextImageIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft):
            const PreviousImageIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const CloseViewerIntent(),
        LogicalKeySet(LogicalKeyboardKey.equal): const ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.minus): const ZoomOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.digit0): const ZoomResetIntent(),
      },
      actions: {
        // Flecha derecha = imagen de la derecha; izquierda = la de la
        // izquierda (el sentido lo da `reverse`).
        NextImageIntent: GuardedAction<NextImageIntent>(
          onInvoke: (_) {
            if (_canGoRight(items.length)) {
              if (_isNavigationBlocked()) {
                _showBlockedNotice();
              } else {
                _goRight();
              }
            }
            return null;
          },
        ),
        PreviousImageIntent: GuardedAction<PreviousImageIntent>(
          onInvoke: (_) {
            if (_canGoLeft(items.length)) {
              if (_isNavigationBlocked()) {
                _showBlockedNotice();
              } else {
                _goLeft();
              }
            }
            return null;
          },
        ),
        CloseViewerIntent: CallbackAction<CloseViewerIntent>(
          onInvoke: (_) {
            // Con un campo de texto enfocado, Esc solo le quita el foco.
            if (isTextFieldFocused()) {
              FocusManager.instance.primaryFocus?.unfocus();
              _viewerFocus.requestFocus();
              return null;
            }
            if (widget.showClose && widget.closeEnabled) _close();
            return null;
          },
        ),
        ZoomInIntent: GuardedAction<ZoomInIntent>(
          onInvoke: (_) {
            _zoomIn();
            return null;
          },
        ),
        ZoomOutIntent: GuardedAction<ZoomOutIntent>(
          onInvoke: (_) {
            _zoomOut();
            return null;
          },
        ),
        ZoomResetIntent: GuardedAction<ZoomResetIntent>(
          onInvoke: (_) {
            _resetZoom();
            return null;
          },
        ),
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: showPanel
            ? Row(
                children: [
                  Expanded(child: viewer),
                  const VerticalDivider(width: 1),
                  SizedBox(
                    width: AppSizes.reviewPanelWidth(width),
                    // La key (imagen + rol) evita reutilizar el estado (y los
                    // controllers de texto) de la imagen o el rol anteriores.
                    child: ImageReviewPanel(
                      key: ValueKey('${item.messageId}-${rol.name}'),
                      target: ImageReviewTarget(
                        messageId: item.messageId,
                        chatJid: item.chatJid,
                        shift: item.shift,
                        storagePath: item.storagePath,
                        fechaJornada: item.fechaJornada,
                        messageTimestamp: item.messageTimestamp,
                        localTime: item.localTime,
                        shiftImageIndex: item.shiftImageIndex,
                      ),
                    ),
                  ),
                ],
              )
            : viewer,
      ),
    );
  }
}

class _ImageIndexIndicator extends StatelessWidget {
  final int index;
  final int total;
  const _ImageIndexIndicator({required this.index, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.pillAll,
          color: const Color.fromARGB(167, 211, 208, 208),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: AppSpacing.md,
        ),
        child: Text('${index + 1} de $total'),
      ),
    );
  }
}

class _ImagePager extends ConsumerWidget {
  final ExtendedPageController controller;
  final List<ImageViewItem> items;
  final GlobalKey<ExtendedImageGestureState> Function(String messageId)
  gestureKeyFor;
  final void Function(ExtendedImageGestureState state) onDoubleTap;
  final bool Function(GestureDetails? details) canScrollPage;
  final ValueChanged<int> onPageChanged;
  final bool reverse;
  final bool canGoLeft;
  final bool canGoRight;
  final VoidCallback goLeft;
  final VoidCallback goRight;

  /// Solo true con el panel del formulario visible y sin registro guardado.
  final bool navigationBlocked;
  final VoidCallback onBlockedTap;
  final PointerDownEventListener? onPointerDown;

  const _ImagePager({
    required this.controller,
    required this.items,
    required this.gestureKeyFor,
    required this.onDoubleTap,
    required this.canScrollPage,
    required this.onPageChanged,
    required this.reverse,
    required this.canGoLeft,
    required this.canGoRight,
    required this.goLeft,
    required this.goRight,
    required this.navigationBlocked,
    required this.onBlockedTap,
    required this.onPointerDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget pager = ExtendedImageGesturePageView.builder(
      controller: controller,
      reverse: reverse,
      canScrollPage: canScrollPage,
      onPageChanged: onPageChanged,
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        final urlAsync = ref.watch(imageUrlProvider(item.storagePath));
        return _ImageCanvas(
          key: ValueKey(item.messageId),
          gestureKey: gestureKeyFor(item.messageId),
          urlAsync: urlAsync,
          onDoubleTap: onDoubleTap,
        );
      },
    );
    final onPointerDown = this.onPointerDown;
    if (onPointerDown != null) {
      pager = Listener(onPointerDown: onPointerDown, child: pager);
    }

    return Stack(
      children: [
        pager,
        if (canGoLeft)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_left,
              enabled: !navigationBlocked,
              tooltip: navigationBlocked ? _blockedAdvanceMessage : null,
              onTap: navigationBlocked ? onBlockedTap : goLeft,
            ),
          ),
        if (canGoRight)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_right,
              enabled: !navigationBlocked,
              tooltip: navigationBlocked ? _blockedAdvanceMessage : null,
              onTap: navigationBlocked ? onBlockedTap : goRight,
            ),
          ),
      ],
    );
  }
}

class _ImageCanvas extends StatelessWidget {
  final GlobalKey<ExtendedImageGestureState> gestureKey;
  final String urlAsync;
  final void Function(ExtendedImageGestureState state) onDoubleTap;

  const _ImageCanvas({
    super.key,
    required this.gestureKey,
    required this.urlAsync,
    required this.onDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    return ExtendedImage.network(
      urlAsync,
      fit: BoxFit.contain,
      cache: true,
      mode: ExtendedImageMode.gesture,
      extendedImageGestureKey: gestureKey,
      onDoubleTap: onDoubleTap,
      initGestureConfigHandler: (ExtendedImageState state) {
        return GestureConfig(
          minScale: _minZoomScale,
          maxScale: _maxZoomScale,
          animationMinScale: _minZoomScale,
          animationMaxScale: _maxZoomScale * 1.1,
          initialScale: _minZoomScale,
          inPageView: true,
          initialAlignment: InitialAlignment.center,
        );
      },
      loadStateChanged: (ExtendedImageState state) {
        switch (state.extendedImageLoadState) {
          case LoadState.loading:
            return const SizedBox(
              height: 200,
              width: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          case LoadState.completed:
            return null;
          case LoadState.failed:
            return GestureDetector(
              onTap: () => state.reLoadImage(),
              child: const SizedBox(
                height: 200,
                width: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 40),
                      SizedBox(height: AppSpacing.sm),
                      Text('Toca para reintentar'),
                    ],
                  ),
                ),
              ),
            );
        }
      },
    );
  }
}

class _ViwerTopBar extends StatelessWidget {
  final String name;
  final String localTime;
  final String shift;
  final bool isEdited;
  final int? shiftImageIndex;
  final VoidCallback zoomOut;
  final VoidCallback zoomIn;
  final VoidCallback zoomRest;
  final VoidCallback? close;
  final String? closeLabel;
  final bool closeEnabled;
  final List<Widget> actions;

  const _ViwerTopBar({
    required this.name,
    required this.localTime,
    required this.shift,
    required this.isEdited,
    this.shiftImageIndex,
    required this.zoomOut,
    required this.zoomIn,
    required this.zoomRest,
    required this.close,
    required this.closeLabel,
    required this.closeEnabled,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _ViewerTopBarMobile(
        name: name,
        localTime: localTime,
        shift: shift,
        isEdited: isEdited,
        shiftImageIndex: shiftImageIndex,
        zoomOut: zoomOut,
        zoomIn: zoomIn,
        zoomRest: zoomRest,
        close: close,
        closeLabel: closeLabel,
        closeEnabled: closeEnabled,
        actions: actions,
      ),
      desktop: _ViewerTopBarDesktop(
        name: name,
        localTime: localTime,
        shift: shift,
        isEdited: isEdited,
        shiftImageIndex: shiftImageIndex,
        zoomOut: zoomOut,
        zoomIn: zoomIn,
        zoomRest: zoomRest,
        close: close,
        closeLabel: closeLabel,
        closeEnabled: closeEnabled,
        actions: actions,
      ),
    );
  }
}

class _ViewerTopBarMobile extends StatelessWidget {
  final String name;
  final String localTime;
  final String shift;
  final bool isEdited;
  final int? shiftImageIndex;
  final VoidCallback zoomOut;
  final VoidCallback zoomIn;
  final VoidCallback zoomRest;
  final VoidCallback? close;
  final String? closeLabel;
  final bool closeEnabled;
  final List<Widget> actions;

  const _ViewerTopBarMobile({
    required this.name,
    required this.localTime,
    required this.shift,
    required this.isEdited,
    this.shiftImageIndex,
    required this.zoomOut,
    required this.zoomIn,
    required this.zoomRest,
    required this.close,
    required this.closeLabel,
    required this.closeEnabled,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 40.0;
    const double fontSize = 14.0;
    const double iconSize = 24.0;

    final controls = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Zoom -',
          onPressed: zoomOut,
          icon: const Icon(Icons.zoom_out_rounded, size: iconSize),
        ),
        IconButton(
          tooltip: 'Reset',
          onPressed: zoomRest,
          icon: const Icon(Icons.refresh, size: iconSize),
        ),
        IconButton(
          tooltip: 'Zoom +',
          onPressed: zoomIn,
          icon: const Icon(Icons.zoom_in_rounded, size: iconSize),
        ),
        ...actions,
        ?_closeButton(close, closeLabel, iconSize, closeEnabled),
      ],
    );

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/blank-profile.png',
            width: avatarSize,
            fit: BoxFit.cover,
            cacheWidth: (avatarSize * 2).round(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
              SelectableText(
                localTime,
                style: const TextStyle(fontSize: fontSize),
              ),
              SelectableText(shift, style: const TextStyle(fontSize: fontSize)),
              if (shiftImageIndex != null)
                SelectableText(
                  '# $shiftImageIndex',
                  style: const TextStyle(fontSize: fontSize),
                ),
              if (isEdited)
                SelectableText(
                  'Editado',
                  style: const TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.errorMessage,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [controls, const SizedBox(height: 10), info],
      ),
    );
  }
}

class _ViewerTopBarDesktop extends StatelessWidget {
  final String name;
  final String localTime;
  final String shift;
  final bool isEdited;
  final int? shiftImageIndex;
  final VoidCallback zoomOut;
  final VoidCallback zoomIn;
  final VoidCallback zoomRest;
  final VoidCallback? close;
  final String? closeLabel;
  final bool closeEnabled;
  final List<Widget> actions;

  const _ViewerTopBarDesktop({
    required this.name,
    required this.localTime,
    required this.shift,
    required this.isEdited,
    this.shiftImageIndex,
    required this.zoomOut,
    required this.zoomIn,
    required this.zoomRest,
    required this.close,
    required this.closeLabel,
    required this.closeEnabled,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 55.0;
    const double fontSize = 16.0;
    const double iconSize = 28.0;

    final controls = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Zoom -',
          onPressed: zoomOut,
          icon: const Icon(Icons.zoom_out_rounded, size: iconSize),
        ),
        IconButton(
          tooltip: 'Reset',
          onPressed: zoomRest,
          icon: const Icon(Icons.refresh, size: iconSize),
        ),
        IconButton(
          tooltip: 'Zoom +',
          onPressed: zoomIn,
          icon: const Icon(Icons.zoom_in_rounded, size: iconSize),
        ),
        ...actions,
        ?_closeButton(close, closeLabel, iconSize, closeEnabled),
      ],
    );

    final info = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/blank-profile.png',
            width: avatarSize,
            fit: BoxFit.cover,
            cacheWidth: (avatarSize * 2).round(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
              SelectableText(
                localTime,
                style: const TextStyle(fontSize: fontSize),
              ),
              SelectableText(shift, style: const TextStyle(fontSize: fontSize)),
              if (shiftImageIndex != null)
                SelectableText(
                  '# $shiftImageIndex',
                  style: const TextStyle(fontSize: fontSize),
                ),
              if (isEdited)
                SelectableText(
                  'Editado',
                  style: const TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: AppColors.errorMessage,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(child: info),
          const SizedBox(width: 8),
          controls,
        ],
      ),
    );
  }
}

/// Botón de cerrar de la barra: icono (el visor del chat) o, con [label], un
/// botón con texto. Sin [close] no hay botón.
Widget? _closeButton(
  VoidCallback? close,
  String? label,
  double iconSize,
  bool enabled,
) {
  if (close == null) return null;
  if (label != null) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: ElevatedButton(
        onPressed: enabled ? close : null,
        child: Text(label),
      ),
    );
  }
  return IconButton(
    tooltip: 'Cerrar',
    onPressed: enabled ? close : null,
    icon: Icon(Icons.close, size: iconSize),
  );
}
