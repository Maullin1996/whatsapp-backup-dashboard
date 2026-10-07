import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/shared/widget/pick_single_date.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/helpers/group_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/pages/group_winners_page.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/group_matches_tile.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/matches_skeleton.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Coincidencias de números ganadores contra lo que registró el Revisor, por
/// fecha (`image-review-domain`, regla 7): una tarjeta por grupo con su
/// cantidad de ganadores; tocarla abre sus ganadores (`GroupWinnersPage`).
///
/// Lee datos reales (`FirestoreMatchesRepository`); solo admin y superAdmin
/// (`/matches`, desde el menú "Coincidencias").
class MatchesPage extends ConsumerWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ResponsiveLayout(
      mobile: _MatchesScaffold(titleStyle: AppTypography.adminAppBarTitle),
      desktop: _MatchesScaffold(
        titleStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }
}

class _MatchesScaffold extends ConsumerWidget {
  final TextStyle titleStyle;

  const _MatchesScaffold({required this.titleStyle});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(matchesDateProvider.notifier);
    final picked = await pickSingleDate(
      context,
      initialDate: ref.read(matchesDateProvider),
    );
    if (picked != null) notifier.select(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Coincidencias', style: titleStyle),
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Volver',
          // Con un enlace directo no hay historial al que volver.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Elegir fecha',
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: () => _pickDate(context, ref),
          ),
        ],
      ),
      backgroundColor: AppColors.screenBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.summaryListMaxWidth,
          ),
          child: const Column(
            children: [
              _DateBar(),
              Expanded(child: _MatchesContent()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fecha activa en español y acceso rápido a "Hoy" si no es hoy.
class _DateBar extends ConsumerWidget {
  const _DateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(matchesDateProvider);
    final isToday = date == DateUtils.dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.today_rounded, color: AppColors.accentTeal),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              formatLongDate(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headerTitle(context),
            ),
          ),
          if (!isToday)
            TextButton(
              onPressed: () => ref.read(matchesDateProvider.notifier).today(),
              child: const Text('Hoy'),
            ),
        ],
      ),
    );
  }
}

class _MatchesContent extends ConsumerWidget {
  const _MatchesContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(dayMatchesProvider);

    return AnimatedSwitcher(
      duration: AppDurations.stateSwitch,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: matches.when(
        loading: () => const KeyedSubtree(
          key: ValueKey('loading'),
          child: MatchesSkeleton(),
        ),
        error: (error, _) => KeyedSubtree(
          key: const ValueKey('error'),
          child: _MessageState(
            icon: Icons.error_outline_rounded,
            message: mapFailureToMessage(error),
            actionLabel: 'Reintentar',
            onAction: () => ref.invalidate(dayMatchesProvider),
          ),
        ),
        data: (day) {
          final groups = groupMatchesOf(day);
          // Los ganadores del día son los mismos en todas las jornadas.
          final hasWinningNumbers = day.jornadas.any(
            (j) => j.winningNumbers.isNotEmpty,
          );
          if (groups.isEmpty) {
            return KeyedSubtree(
              key: const ValueKey('empty'),
              child: _MessageState(
                icon: Icons.emoji_events_outlined,
                message: hasWinningNumbers
                    ? 'Ningún grupo tuvo ganadores en esta fecha'
                    : 'Aún no hay números ganadores para esta fecha',
              ),
            );
          }
          return KeyedSubtree(
            key: const ValueKey('data'),
            child: _GroupsList(groups: groups),
          );
        },
      ),
    );
  }
}

/// Una tarjeta por grupo con ganadores (los que más tienen primero).
class _GroupsList extends StatelessWidget {
  final List<GroupMatches> groups;

  const _GroupsList({required this.groups});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, i) => GroupMatchesTile(
        group: groups[i],
        onTap: () => context.push(groupWinnersLocation(groups[i].chatJid)),
      ),
    );
  }
}

/// Estado vacío o de error: icono, mensaje y, opcionalmente, una acción.
class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSizes.emptyStateMaxWidth,
        ),
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
      ),
    );
  }
}
