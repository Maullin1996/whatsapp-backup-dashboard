import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/shared/widget/pick_single_date.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/summary_providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/summary_overview.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/pages/summary_role_detail_page.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_group_tile.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_skeleton.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Resumen por grupo y jornada de un día: qué registró cada rol y si cuadra.
///
/// Una lista de grupos (los que tienen problemas primero), cada uno con dos
/// tarjetas, Revisor y Sumador, que muestran el total sumado y las jornadas
/// registradas; tocar una abre su detalle por jornada
/// (`SummaryRoleDetailPage`).
///
/// Lee datos reales de Firestore (ver `summaryRepositoryProvider`); solo para
/// admin y superAdmin.
class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ResponsiveLayout(
      mobile: _SummaryScaffold(titleStyle: AppTypography.adminAppBarTitle),
      desktop: _SummaryScaffold(
        titleStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }
}

class _SummaryScaffold extends ConsumerWidget {
  final TextStyle titleStyle;

  const _SummaryScaffold({required this.titleStyle});

  Future<void> _pickDate(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(summaryDateProvider.notifier);
    final picked = await pickSingleDate(
      context,
      initialDate: ref.read(summaryDateProvider),
    );
    if (picked != null) notifier.select(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resumen', style: titleStyle),
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Volver',
          // Con un enlace directo a /summary no hay historial al que volver.
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(reloadJornadaSummariesProvider)(),
          ),
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
              Expanded(child: _SummaryContent()),
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
    final date = ref.watch(summaryDateProvider);
    final isToday = date == DateUtils.dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
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
              onPressed: () => ref.read(summaryDateProvider.notifier).today(),
              child: const Text('Hoy'),
            ),
        ],
      ),
    );
  }
}

class _SummaryContent extends ConsumerWidget {
  const _SummaryContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(jornadaSummariesProvider);

    return AnimatedSwitcher(
      duration: AppDurations.stateSwitch,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: summaries.when(
        loading: () => const KeyedSubtree(
          key: ValueKey('loading'),
          child: SummarySkeleton(),
        ),
        error: (error, _) => KeyedSubtree(
          key: const ValueKey('error'),
          child: _MessageState(
            icon: Icons.error_outline_rounded,
            message: mapFailureToMessage(error),
            actionLabel: 'Reintentar',
            // A la fuente, nunca a la caché.
            onAction: () => ref.read(reloadJornadaSummariesProvider)(),
          ),
        ),
        data: (list) => list.isEmpty
            ? const KeyedSubtree(
                key: ValueKey('empty'),
                child: _MessageState(
                  icon: Icons.fact_check_rounded,
                  message: 'No hay reportes registrados para esta fecha',
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('data'),
                child: _SummaryList(summaries: list),
              ),
      ),
    );
  }
}

/// Un [SummaryGroupTile] por grupo, con los que necesitan atención primero.
class _SummaryList extends ConsumerWidget {
  final List<JornadaSummary> summaries;

  const _SummaryList({required this.summaries});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Una sola lectura del reloj para todo lo que se construye aquí.
    final now = ref.watch(clockProvider)();
    final groups = groupsBySeverity(summaries, now);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, i) => SummaryGroupTile(
        jornadas: groups[i],
        now: now,
        onOpenRole: (rol) => context.push(
          summaryRoleDetailLocation(groups[i].first.chatJid, rol),
        ),
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
