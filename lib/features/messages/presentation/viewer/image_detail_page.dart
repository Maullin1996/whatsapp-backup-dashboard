import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/controllers/image_zoom_controller.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/image_view_item.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/chat_image_items_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/messages_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_controler_actions.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/widgets/nav_button.dart';

class ImageDetailPage extends ConsumerStatefulWidget {
  final int initialIndex;

  const ImageDetailPage({super.key, required this.initialIndex});

  @override
  ConsumerState<ImageDetailPage> createState() => _ImageDetailPageState();
}

class _ImageDetailPageState extends ConsumerState<ImageDetailPage> {
  late final PageController _controller;
  late final ImageZoomController _zoom;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: _index);
    _zoom = ImageZoomController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _zoom.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _zoom.reset();
    final items = ref.read(chatImageItemsProvider);
    if (index >= items.length - 3) {
      ref.read(messagesProvider.notifier).loadMore();
    }
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
                duration: const Duration(milliseconds: 200),
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
                duration: const Duration(milliseconds: 200),
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
            _zoom.zoomIn();
            return null;
          },
        ),
        ZoomOutIntent: CallbackAction<ZoomOutIntent>(
          onInvoke: (_) {
            _zoom.zoomOut();
            return null;
          },
        ),
        ZoomResetIntent: CallbackAction<ZoomResetIntent>(
          onInvoke: (_) {
            _zoom.reset();
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
              zoomOut: _zoom.zoomOut,
              zoomIn: _zoom.zoomIn,
              zoomRest: _zoom.reset,
              close: () => Navigator.pop(context),
            ),
            Expanded(
              child: _ImagePager(
                currentIndex: _index,
                controller: _controller,
                items: items,
                zoom: _zoom,
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
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color.fromARGB(167, 211, 208, 208),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        child: Text('${index + 1} de $total'),
      ),
    );
  }
}

class _ImagePager extends ConsumerWidget {
  final PageController controller;
  final List<ImageViewItem> items;
  final ImageZoomController zoom;
  final ValueChanged<int> onPageChanged;
  final int currentIndex;

  const _ImagePager({
    required this.controller,
    required this.items,
    required this.zoom,
    required this.onPageChanged,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Stack(
      children: [
        PageView.builder(
          controller: controller,
          itemCount: items.length,
          reverse: true,
          onPageChanged: onPageChanged,
          itemBuilder: (_, index) {
            final item = items[index];
            final urlAsync = ref.watch(imageUrlProvider(item.storagePath));
            return _ImageCanvas(zoom: zoom, urlAsync: urlAsync);
          },
        ),
        if (currentIndex > 0)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_left,
              onTap: () => controller.previousPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ),
            ),
          ),
        if (currentIndex < items.length - 1)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: NavButton(
              icon: Icons.chevron_right,
              onTap: () => controller.nextPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageCanvas extends StatelessWidget {
  final ImageZoomController zoom;
  final String urlAsync;
  const _ImageCanvas({required this.zoom, required this.urlAsync});

  @override
  Widget build(BuildContext context) {
    //final screenWidth = MediaQuery.sizeOf(context).width;
    //final isMobile = screenWidth < 700;
    //final cacheDimension = isMobile ? (screenWidth * 1.25).round() : 1600;

    return Center(
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            zoom.onScroll(event);
          }
        },
        child: GestureDetector(
          onDoubleTap: () => zoom.reset(),
          child: InteractiveViewer(
            transformationController: zoom.tc,
            minScale: ImageZoomController.minScale,
            maxScale: ImageZoomController.maxScale,
            panEnabled: true,
            scaleEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            child: ExtendedImage.network(
              urlAsync,
              fit: BoxFit.contain,
              cache: true,
              loadStateChanged: (ExtendedImageState state) {
                switch (state.extendedImageLoadState) {
                  case LoadState.loading:
                    return SizedBox(
                      height: 200,
                      width: 200,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  case LoadState.completed:
                    return null; // Muestra la imagen normalmente
                  case LoadState.failed:
                    return GestureDetector(
                      onTap: () {
                        state.reLoadImage();
                      },
                      child: SizedBox(
                        height: 200,
                        width: 200,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image, size: 40),
                              SizedBox(height: 8),
                              Text('Toca para reintentar'),
                            ],
                          ),
                        ),
                      ),
                    );
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ViwerTopBar extends StatelessWidget {
  final String name;
  final String localTime;
  final String shift;
  final VoidCallback zoomOut;
  final VoidCallback zoomIn;
  final VoidCallback zoomRest;
  final VoidCallback close;

  const _ViwerTopBar({
    required this.name,
    required this.localTime,
    required this.shift,
    required this.zoomOut,
    required this.zoomIn,
    required this.zoomRest,
    required this.close,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 700;
    final avatarSize = isMobile ? 40.0 : 55.0;
    final fontSize = isMobile ? 14.0 : 16.0;
    final iconSize = isMobile ? 24.0 : 28.0;

    final controls = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Zoom -',
          onPressed: zoomOut,
          icon: Icon(Icons.zoom_out_rounded, size: iconSize),
        ),
        IconButton(
          tooltip: 'Reset',
          onPressed: zoomRest,
          icon: Icon(Icons.refresh, size: iconSize),
        ),
        IconButton(
          tooltip: 'Zoom +',
          onPressed: zoomIn,
          icon: Icon(Icons.zoom_in_rounded, size: iconSize),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: close,
          icon: Icon(Icons.close, size: iconSize),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
              SelectableText(localTime, style: TextStyle(fontSize: fontSize)),
              SelectableText(shift, style: TextStyle(fontSize: fontSize)),
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [controls, const SizedBox(height: 10), info],
            )
          : Row(
              children: [
                Expanded(child: info),
                const SizedBox(width: 8),
                controls,
              ],
            ),
    );
  }
}
