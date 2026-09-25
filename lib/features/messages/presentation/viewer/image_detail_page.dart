import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/breakpoints.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
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

class ImageDetailPage extends ConsumerStatefulWidget {
  final int initialIndex;

  const ImageDetailPage({super.key, required this.initialIndex});

  @override
  ConsumerState<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends ConsumerState<ImageDetailPage>
    with SingleTickerProviderStateMixin {
  late final ExtendedPageController _controller;
  late int _index;

  /// Una `GlobalKey` de estado de gesto por página, para que el zoom de una
  /// imagen sea independiente del resto (antes se compartía un único
  /// `TransformationController` entre todas las páginas del pager).
  final Map<int, GlobalKey<ExtendedImageGestureState>> _gestureKeys = {};

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

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = ExtendedPageController(initialPage: _index);
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: AppDurations.quick,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _zoomAnimationController.dispose();
    _viewerFocus.dispose();
    super.dispose();
  }

  GlobalKey<ExtendedImageGestureState> _gestureKeyFor(int index) {
    return _gestureKeys.putIfAbsent(
      index,
      () => GlobalKey<ExtendedImageGestureState>(),
    );
  }

  ExtendedImageGestureState? get _currentGestureState =>
      _gestureKeys[_index]?.currentState;

  /// El panel del formulario (y el bloqueo de navegación) solo existen en
  /// pantallas anchas; por debajo el visor es el de siempre.
  bool get _showReviewPanel =>
      MediaQuery.sizeOf(context).width >= AppBreakpoints.reviewForm;

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
    if (!mounted || !_showReviewPanel) return false;
    var id = originId;
    if (id == null) {
      final items = ref.read(chatImageItemsProvider);
      if (items.isEmpty) return false;
      id = items[_index.clamp(0, items.length - 1)].messageId;
    }
    return !ref.read(canAdvanceProvider(id));
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
    setState(() => _index = index);
    // Si el campo enfocado era de la imagen anterior, su foco se perdió.
    if (_showReviewPanel) _viewerFocus.requestFocus();
    final items = ref.read(chatImageItemsProvider);
    if (index >= items.length - 3) {
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
    final items = ref.watch(chatImageItemsProvider);
    if (items.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final safeIndex = _index.clamp(0, items.length - 1);
    final item = items[safeIndex];

    final width = MediaQuery.sizeOf(context).width;
    final showPanel = width >= AppBreakpoints.reviewForm;
    final navigationBlocked =
        showPanel && !ref.watch(canAdvanceProvider(item.messageId));

    // Tras guardar (o re-guardar) el foco vuelve al visor.
    ref.listen(savedRecordProvider(item.messageId), (previous, next) {
      if (showPanel && next.value != null && next.value != previous?.value) {
        _viewerFocus.requestFocus();
      }
    });

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
          close: () => Navigator.pop(context),
        ),
        Expanded(
          child: _ImagePager(
            currentIndex: _index,
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
        NextImageIntent: GuardedAction<NextImageIntent>(
          onInvoke: (_) {
            if (_index > 0) {
              if (_isNavigationBlocked()) {
                _showBlockedNotice();
              } else {
                _controller.previousPage(
                  duration: AppDurations.quick,
                  curve: Curves.easeOut,
                );
              }
            }
            return null;
          },
        ),
        PreviousImageIntent: GuardedAction<PreviousImageIntent>(
          onInvoke: (_) {
            if (_index < items.length - 1) {
              if (_isNavigationBlocked()) {
                _showBlockedNotice();
              } else {
                _controller.nextPage(
                  duration: AppDurations.quick,
                  curve: Curves.easeOut,
                );
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
            Navigator.pop(context);
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
                    // La key evita reutilizar el estado (y los controllers de
                    // texto) de la imagen anterior al cambiar de imagen.
                    child: ImageReviewPanel(
                      key: ValueKey(item.messageId),
                      target: ImageReviewTarget(
                        messageId: item.messageId,
                        chatJid: item.chatJid,
                        shift: item.shift,
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
  final GlobalKey<ExtendedImageGestureState> Function(int index) gestureKeyFor;
  final void Function(ExtendedImageGestureState state) onDoubleTap;
  final bool Function(GestureDetails? details) canScrollPage;
  final ValueChanged<int> onPageChanged;
  final int currentIndex;

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
    required this.currentIndex,
    required this.navigationBlocked,
    required this.onBlockedTap,
    required this.onPointerDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget pager = ExtendedImageGesturePageView.builder(
      controller: controller,
      reverse: true,
      canScrollPage: canScrollPage,
      onPageChanged: onPageChanged,
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        final urlAsync = ref.watch(imageUrlProvider(item.storagePath));
        return _ImageCanvas(
          key: ValueKey(item.storagePath),
          gestureKey: gestureKeyFor(index),
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
        // El pager va en reverse: la izquierda avanza en el índice.
        if (currentIndex < items.length - 1)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_left,
              enabled: !navigationBlocked,
              tooltip: navigationBlocked ? _blockedAdvanceMessage : null,
              onTap: () {
                if (navigationBlocked) {
                  onBlockedTap();
                } else {
                  controller.nextPage(
                    duration: AppDurations.quick,
                    curve: Curves.easeOut,
                  );
                }
              },
            ),
          ),
        if (currentIndex > 0)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_right,
              enabled: !navigationBlocked,
              tooltip: navigationBlocked ? _blockedAdvanceMessage : null,
              onTap: () {
                if (navigationBlocked) {
                  onBlockedTap();
                } else {
                  controller.previousPage(
                    duration: AppDurations.quick,
                    curve: Curves.easeOut,
                  );
                }
              },
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
  final VoidCallback close;

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
  final VoidCallback close;

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
        IconButton(
          tooltip: 'Cerrar',
          onPressed: close,
          icon: const Icon(Icons.close, size: iconSize),
        ),
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
              SelectableText(
                shift,
                style: const TextStyle(fontSize: fontSize),
              ),
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
  final VoidCallback close;

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
        IconButton(
          tooltip: 'Cerrar',
          onPressed: close,
          icon: const Icon(Icons.close, size: iconSize),
        ),
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
              SelectableText(
                shift,
                style: const TextStyle(fontSize: fontSize),
              ),
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
