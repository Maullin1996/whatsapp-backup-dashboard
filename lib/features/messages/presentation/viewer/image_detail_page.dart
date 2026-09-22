import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_controler_actions.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/nav_button.dart';

/// Escala mínima/máxima permitida al hacer zoom en el visor.
const double _minZoomScale = 1.0;
const double _maxZoomScale = 6.0;

/// Escala a la que salta el doble-tap/doble-click cuando la imagen está a
/// escala 1.0 (un segundo doble tap vuelve a 1.0).
const double _doubleTapZoomScale = 2.5;

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

  void _onPageChanged(int index) {
    setState(() => _index = index);
    final items = ref.read(chatImageItemsProvider);
    if (index >= items.length - 3) {
      ref.read(messagesProvider.notifier).loadMore();
    }
  }

  /// Solo deja que el pager cambie de página cuando la imagen actual está a
  /// escala 1.0. Mientras haya zoom, desplazarse hacia un lateral mueve la
  /// imagen (pan) en vez de cambiar a la foto siguiente/anterior.
  bool _canScrollPage(GestureDetails? details) {
    return (details?.totalScale ?? 1.0) <= 1.0;
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

    return FocusableActionDetector(
      autofocus: true,
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
        NextImageIntent: CallbackAction<NextImageIntent>(
          onInvoke: (_) {
            if (_index < items.length - 1) {
              _controller.nextPage(
                duration: AppDurations.quick,
                curve: Curves.easeOut,
              );
            }
            return null;
          },
        ),
        PreviousImageIntent: CallbackAction<PreviousImageIntent>(
          onInvoke: (_) {
            if (_index > 0) {
              _controller.previousPage(
                duration: AppDurations.quick,
                curve: Curves.easeOut,
              );
            }
            return null;
          },
        ),
        CloseViewerIntent: CallbackAction<CloseViewerIntent>(
          onInvoke: (_) {
            Navigator.pop(context);
            return null;
          },
        ),
        ZoomInIntent: CallbackAction<ZoomInIntent>(
          onInvoke: (_) {
            _zoomIn();
            return null;
          },
        ),
        ZoomOutIntent: CallbackAction<ZoomOutIntent>(
          onInvoke: (_) {
            _zoomOut();
            return null;
          },
        ),
        ZoomResetIntent: CallbackAction<ZoomResetIntent>(
          onInvoke: (_) {
            _resetZoom();
            return null;
          },
        ),
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
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
              ),
            ),
            _ImageIndexIndicator(index: _index, total: items.length),
          ],
        ),
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

  const _ImagePager({
    required this.controller,
    required this.items,
    required this.gestureKeyFor,
    required this.onDoubleTap,
    required this.canScrollPage,
    required this.onPageChanged,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        ExtendedImageGesturePageView.builder(
          controller: controller,
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
        ),
        // Izquierda = retroceder a la imagen anterior.
        if (currentIndex > 0)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_left,
              onTap: () => controller.previousPage(
                duration: AppDurations.quick,
                curve: Curves.easeOut,
              ),
            ),
          ),
        // Derecha = avanzar a la siguiente imagen.
        if (currentIndex < items.length - 1)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_right,
              onTap: () => controller.nextPage(
                duration: AppDurations.quick,
                curve: Curves.easeOut,
              ),
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
