import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/lotteries/lotteries.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/match_entry.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/image_url_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/viewer/image_detail_page.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Ruta `/matches/group?chat=<chatJid>` con los ganadores de un grupo en el
/// día elegido en Coincidencias.
String groupWinnersLocation(String chatJid) =>
    Uri(path: '/matches/group', queryParameters: {'chat': chatJid}).toString();

/// Ganadores de un grupo: una tarjeta por coincidencia con el correo del
/// Revisor, la fecha, la lotería, el número ganador, el código y la imagen.
/// Tocar la imagen la abre en el visor de imágenes (zoom, gestos y paso entre
/// las imágenes de los ganadores del grupo). Lee el mismo provider que la
/// lista; solo admin y superAdmin.
class GroupWinnersPage extends ConsumerWidget {
  final String chatJid;

  const GroupWinnersPage({super.key, required this.chatJid});

  void _openViewer(BuildContext context, WidgetRef ref, MatchEntry match) {
    final items = ref.read(groupImageItemsProvider(chatJid));
    final index = items.indexWhere((i) => i.messageId == match.messageId);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageDetailPage(
          initialIndex: index < 0 ? 0 : index,
          items: groupImageItemsProvider(chatJid),
          reverse: false,
          paginate: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(groupMatchesListProvider);
    final date = ref.watch(matchesDateProvider);
    final group = groups.value?.where((g) => g.chatJid == chatJid).firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: Text(group?.groupName ?? 'Ganadores'),
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/matches'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(dayMatchesProvider),
          ),
        ],
      ),
      backgroundColor: AppColors.screenBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.summaryListMaxWidth,
          ),
          child: groups.when(
            loading: () => const _Skeleton(),
            error: (error, _) => _Message(
              icon: Icons.error_outline_rounded,
              message: mapFailureToMessage(error),
              actionLabel: 'Reintentar',
              onAction: () => ref.invalidate(dayMatchesProvider),
            ),
            data: (_) => group == null || group.winners == 0
                ? const _Message(
                    icon: Icons.emoji_events_outlined,
                    message: 'Este grupo no tiene ganadores en esta fecha',
                  )
                : ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Text(
                          '${group.winners == 1 ? '1 ganador' : '${group.winners} ganadores'}'
                          ' · ${formatLongDate(date)}',
                          style: AppTypography.headerTitle(context),
                        ),
                      ),
                      for (final match in group.matches) ...[
                        _WinnerCard(
                          match: match,
                          onOpenImage: () => _openViewer(context, ref, match),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// `yyyy-MM-dd` -> `dd/MM/yyyy`; el texto tal cual si no tiene ese formato.
String _dmy(String fechaJornada) {
  final parts = fechaJornada.split('-');
  return parts.length == 3
      ? '${parts[2]}/${parts[1]}/${parts[0]}'
      : fechaJornada;
}

class _WinnerCard extends StatelessWidget {
  final MatchEntry match;
  final VoidCallback onOpenImage;

  const _WinnerCard({required this.match, required this.onOpenImage});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final loteria = match.loteria;
    final codigo = match.codigo;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loteria != null && loteria.isNotEmpty)
          Text(
            loteriaDisplayName(loteria),
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.accentTeal,
            ),
          ),
        Text(
          match.numero,
          style: textTheme.headlineMedium
              ?.merge(AppTypography.tabular)
              .copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          'Número ganador',
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: AppSpacing.md),
        if (match.winningNumbers.isNotEmpty)
          _Field(
            icon: Icons.emoji_events_outlined,
            label: 'Número de la lotería',
            value: match.winningNumbers.join(' · '),
            tabular: true,
            bold: true,
          ),
        _Field(
          icon: Icons.mail_outline_rounded,
          label: 'Revisor',
          value: match.revisorEmail.isEmpty ? '—' : match.revisorEmail,
        ),
        _Field(
          icon: Icons.event_rounded,
          label: 'Fecha',
          value: '${_dmy(match.fechaJornada)} · ${match.localTime}',
        ),
        _Field(
          icon: Icons.tag_rounded,
          label: 'Código',
          value: codigo == null || codigo.isEmpty ? '—' : codigo,
          tabular: true,
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final image = _WinnerImage(
            storagePath: match.storagePath,
            onTap: onOpenImage,
          );
          if (constraints.maxWidth >= 520) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: info),
                const SizedBox(width: AppSpacing.lg),
                SizedBox(width: 200, child: image),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              info,
              const SizedBox(height: AppSpacing.md),
              image,
            ],
          );
        },
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool tabular;
  final bool bold;

  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    this.tabular = false,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey.shade600),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$label: ',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style:
                  (tabular
                          ? textTheme.bodyMedium?.merge(AppTypography.tabular)
                          : textTheme.bodyMedium)
                      ?.copyWith(fontWeight: bold ? FontWeight.w700 : null),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miniatura de la imagen del ganador; tocarla abre el visor.
class _WinnerImage extends ConsumerWidget {
  final String storagePath;
  final VoidCallback onTap;

  const _WinnerImage({required this.storagePath, required this.onTap});

  static const _height = 180.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(imageUrlProvider(storagePath));

    return Tooltip(
      message: 'Ver imagen',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: AppRadius.tileAll,
          child: SizedBox(
            height: _height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExtendedImage.network(
                  url,
                  fit: BoxFit.cover,
                  cache: true,
                  loadStateChanged: (ExtendedImageState state) {
                    switch (state.extendedImageLoadState) {
                      case LoadState.loading:
                        return Container(
                          color: Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      case LoadState.completed:
                        return null;
                      case LoadState.failed:
                        return Container(
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 40),
                          ),
                        );
                    }
                  },
                ),
                const Positioned(
                  right: AppSpacing.sm,
                  bottom: AppSpacing.sm,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.zoom_out_map_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (var i = 0; i < 2; i++) ...[
            Container(
              height: 300,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.cardAll,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Message({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.headerTitle(context),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
