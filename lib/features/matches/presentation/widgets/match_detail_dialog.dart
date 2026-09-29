import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';

/// Ancho máximo del diálogo. No hay un token de `AppSizes` para diálogos (los
/// existentes en `admin/` usan literales 500/600); este contenido es más
/// corto que los de `AssignGroupsDialog`, de ahí el valor más chico.
const _dialogMaxWidth = 480.0;

/// Detalle completo de una coincidencia, abierto con "Ver más" desde
/// `JornadaMatchesSection`.
class MatchDetailDialog extends StatelessWidget {
  final MatchEntry match;

  /// Si el botón "Ver imagen" pide la imagen real (`imageUrlProvider`) o
  /// muestra el aviso de datos de prueba. Por defecto APAGADO: con datos
  /// inventados no existe ninguna imagen real que cargar — el paso 7 lo
  /// enciende. Parámetro solo para tests, igual que `pickSingleDate.isWeb`.
  final bool realImageEnabled;

  static const _defaultRealImageEnabled = false;

  const MatchDetailDialog({
    super.key,
    required this.match,
    @visibleForTesting this.realImageEnabled = _defaultRealImageEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _DialogShell(
        match: match,
        realImageEnabled: realImageEnabled,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
      ),
      desktop: _DialogShell(
        match: match,
        realImageEnabled: realImageEnabled,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 80,
          vertical: AppSpacing.xl,
        ),
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  final MatchEntry match;
  final bool realImageEnabled;
  final EdgeInsets insetPadding;

  const _DialogShell({
    required this.match,
    required this.realImageEnabled,
    required this.insetPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: insetPadding,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _dialogMaxWidth),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Detalle de la coincidencia',
                        style: AppTypography.headerTitle(context),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _DetailRow(label: 'Número', value: match.numero, tabular: true),
                _DetailRow(label: 'Enviado por', value: match.senderName),
                _DetailRow(
                  label: 'Grupo',
                  value: '${match.groupName} (${match.chatJid})',
                ),
                _DetailRow(label: 'Hora', value: match.localTime),
                _DetailRow(
                  label: 'Jornada',
                  value: shortShiftName(match.shift),
                ),
                _DetailRow(
                  label: 'Referencia de la imagen',
                  value: match.storagePath,
                ),
                _DetailRow(
                  label: 'Mensaje editado',
                  value: match.messageEdited ? 'Sí' : 'No',
                ),
                const SizedBox(height: AppSpacing.md),
                _MatchImageSection(
                  storagePath: match.storagePath,
                  realImageEnabled: realImageEnabled,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool tabular;

  const _DetailRow({
    required this.label,
    required this.value,
    this.tabular = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: value,
              style: tabular ? AppTypography.tabular : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Imagen bajo demanda: no se pide hasta tocar "Ver imagen". Con
/// [realImageEnabled] apagado (el caso de hoy, con datos inventados) nunca
/// llega a leer `imageUrlProvider` ni construye un `ExtendedImage`.
class _MatchImageSection extends StatefulWidget {
  final String storagePath;
  final bool realImageEnabled;

  const _MatchImageSection({
    required this.storagePath,
    required this.realImageEnabled,
  });

  @override
  State<_MatchImageSection> createState() => _MatchImageSectionState();
}

class _MatchImageSectionState extends State<_MatchImageSection> {
  bool _requested = false;

  @override
  Widget build(BuildContext context) {
    if (!_requested) {
      return Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _requested = true),
          icon: const Icon(Icons.image_outlined),
          label: const Text('Ver imagen'),
        ),
      );
    }

    if (!widget.realImageEnabled) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: AppRadius.tileAll,
        ),
        child: Row(
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(
              child: Text('Imagen no disponible con datos de prueba'),
            ),
          ],
        ),
      );
    }

    return _RealMatchImage(storagePath: widget.storagePath);
  }
}

/// Calcado del `loadStateChanged` de `_MediaPreview`
/// (`message_bubble.dart`): mismos tres estados (carga / completo / error
/// con reintento).
class _RealMatchImage extends ConsumerWidget {
  final String storagePath;

  const _RealMatchImage({required this.storagePath});

  static const _height = 220.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(imageUrlProvider(storagePath));

    return ClipRRect(
      borderRadius: AppRadius.tileAll,
      child: ExtendedImage.network(
        url,
        height: _height,
        fit: BoxFit.cover,
        cache: true,
        loadStateChanged: (ExtendedImageState state) {
          switch (state.extendedImageLoadState) {
            case LoadState.loading:
              return Container(
                height: _height,
                color: Colors.black12,
                child: const Center(child: CircularProgressIndicator()),
              );
            case LoadState.completed:
              return null;
            case LoadState.failed:
              return GestureDetector(
                onTap: () => state.reLoadImage(),
                child: Container(
                  height: _height,
                  color: Colors.black12,
                  child: const Center(
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
      ),
    );
  }
}
