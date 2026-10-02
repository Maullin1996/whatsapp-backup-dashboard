import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/shared/widget/pick_single_date.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/matches/domain/entities/jornada_matches.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/providers/matches_providers.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/jornada_matches_section.dart';
import 'package:whatsapp_monitor_viewer/features/matches/presentation/widgets/matches_skeleton.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Coincidencias de números ganadores contra lo que registró el Revisor, por
/// fecha y jornada (`image-review-domain`, regla 7).
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
      backgroundColor: Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.adminPanelMaxWidth,
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
        // Siempre una lista por jornada (cada una dice "Todavía no hay
        // ganadores" si no tiene coincidencias); el vacío de página queda
        // solo para un día sin ninguna jornada.
        data: (day) => day.jornadas.isEmpty
            ? const KeyedSubtree(
                key: ValueKey('empty'),
                child: _MessageState(
                  icon: Icons.emoji_events_outlined,
                  message: 'Aún no hay números ganadores para esta fecha',
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('data'),
                child: _MatchesList(jornadas: day.jornadas),
              ),
      ),
    );
  }
}

/// Una sección por jornada, en el orden en que llega (nunca combinadas en un
/// total del día — `image-review-domain`, reglas 4 y 5).
class _MatchesList extends StatelessWidget {
  final List<JornadaMatches> jornadas;

  const _MatchesList({required this.jornadas});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        for (final jornada in jornadas) ...[
          JornadaMatchesSection(jornada: jornada),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
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
