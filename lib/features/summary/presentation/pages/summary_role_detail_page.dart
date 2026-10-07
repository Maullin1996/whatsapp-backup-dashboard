import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/loading/app_shimmer.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';
import 'package:whatsapp_monitor_viewer/core/time/jornada_labels.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/domain/entities/review_role.dart';
import 'package:whatsapp_monitor_viewer/features/image_review/presentation/models/review_key.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/entities/jornada_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/domain/helpers/role_group_summary.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/providers/summary_providers.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_role_card.dart';
import 'package:whatsapp_monitor_viewer/features/summary/presentation/widgets/summary_status_pill.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_long_date.dart';
import 'package:whatsapp_monitor_viewer/helpers/format_pesos.dart';
import 'package:whatsapp_monitor_viewer/helpers/map_failure_to_message.dart';

/// Ruta `/summary/detail?chat=<chatJid>&role=<revisor|sumador>` de [rol] en un
/// grupo, con el día elegido en el Resumen.
String summaryRoleDetailLocation(String chatJid, ReviewRole rol) => Uri(
  path: '/summary/detail',
  queryParameters: {'chat': chatJid, 'role': rol.name},
).toString();

/// Detalle de un rol en un grupo: el total del día, cuántos tickets e
/// imágenes registró, qué jornadas le faltan por llenar y, jornada por
/// jornada, sus cifras. Lee del mismo provider (y la misma caché) que la
/// lista del Resumen; solo admin y superAdmin.
class SummaryRoleDetailPage extends ConsumerWidget {
  final String chatJid;
  final ReviewRole rol;

  const SummaryRoleDetailPage({
    super.key,
    required this.chatJid,
    required this.rol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(summaryDateProvider);
    final summaries = ref.watch(jornadaSummariesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(rol.label),
        backgroundColor: Colors.white,
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/summary'),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(reloadJornadaSummariesProvider)(),
          ),
        ],
      ),
      backgroundColor: AppColors.screenBackground,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSizes.summaryListMaxWidth,
          ),
          child: summaries.when(
            loading: () => const _DetailSkeleton(),
            error: (error, _) => _Message(
              icon: Icons.error_outline_rounded,
              message: mapFailureToMessage(error),
              actionLabel: 'Reintentar',
              onAction: () => ref.read(reloadJornadaSummariesProvider)(),
            ),
            data: (list) {
              final group = [
                for (final s in list)
                  if (s.chatJid == chatJid) s,
              ];
              if (group.isEmpty) {
                return const _Message(
                  icon: Icons.fact_check_rounded,
                  message: 'No hay reportes de este grupo en esta fecha',
                );
              }
              final now = ref.watch(clockProvider)();
              return _DetailBody(
                groupName: group.first.groupName,
                date: date,
                now: now,
                summary: RoleGroupSummary.of(rol, group, now),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final String groupName;
  final DateTime date;
  final DateTime now;
  final RoleGroupSummary summary;

  const _DetailBody({
    required this.groupName,
    required this.date,
    required this.now,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final faltantes = summary.faltantes;

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _TotalsCard(groupName: groupName, date: date, summary: summary),
        if (faltantes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _MissingBanner(
            rol: summary.rol,
            names: [for (final j in faltantes) shortShiftName(j.summary.shift)],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text('Por jornada', style: AppTypography.headerTitle(context)),
        ),
        for (final j in summary.jornadas) ...[
          _JornadaTile(jornada: j, now: now),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// Grupo, fecha y las tres cifras del rol: total, tickets e imágenes.
class _TotalsCard extends StatelessWidget {
  final String groupName;
  final DateTime date;
  final RoleGroupSummary summary;

  const _TotalsCard({
    required this.groupName,
    required this.date,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final registradas = summary.registradas.length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                summaryRoleIcon(summary.rol),
                size: 20,
                color: AppColors.accentTeal,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentTeal,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              formatLongDate(date),
              style: AppTypography.timestamp(
                context,
              ).copyWith(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              registradas == 0 ? '—' : formatPesos(summary.total),
              style: textTheme.headlineMedium
                  ?.merge(AppTypography.tabular)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Text(
            registradas == 0
                ? 'Todavía no registró nada'
                : 'Total sumado · $registradas de ${summary.jornadas.length} '
                      'jornadas',
            style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(label: 'Tickets', value: summary.tickets),
              ),
              Expanded(
                child: _Stat(label: 'Imágenes', value: summary.imagenes),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: textTheme.titleLarge
              ?.merge(AppTypography.tabular)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
        ),
      ],
    );
  }
}

/// Qué jornadas le faltan por llenar al rol.
class _MissingBanner extends StatelessWidget {
  final ReviewRole rol;
  final List<String> names;

  const _MissingBanner({required this.rol, required this.names});

  @override
  Widget build(BuildContext context) {
    const color = AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.tileAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, size: 20, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              names.length == 1
                  ? 'Le falta llenar la jornada ${names.single}'
                  : 'Le faltan por llenar las jornadas ${names.join(', ')}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una jornada del rol: nombre, horario, estado y sus cifras.
class _JornadaTile extends StatelessWidget {
  final RoleJornada jornada;
  final DateTime now;

  const _JornadaTile({required this.jornada, required this.now});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final JornadaSummary s = jornada.summary;
    final role = jornada.role;
    final shift = shiftFromLabel(s.shift);
    final enCurso =
        shift != null && !jornadaTerminada(s.fechaJornada, shift, now);
    final subtitle = [
      ?shiftHoursText(s.shift),
      if (enCurso) 'En curso',
    ].join(' · ');
    final faltan = jornada.imagenesFaltantes;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortShiftName(s.shift),
                    style: AppTypography.headerTitle(context),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppTypography.timestamp(
                        context,
                      ).copyWith(color: Colors.grey.shade700),
                    ),
                ],
              ),
              role.registrado
                  ? const SummaryStatusPill(
                      label: 'Registrada',
                      icon: Icons.check_circle_rounded,
                      color: AppColors.success,
                    )
                  : const SummaryStatusPill(
                      label: 'Falta por llenar',
                      icon: Icons.hourglass_top_rounded,
                      color: AppColors.warning,
                    ),
            ],
          ),
          if (role.registrado) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _Stat(label: 'Tickets', value: role.cantidadTickets),
                ),
                Expanded(
                  child: _Stat(label: 'Imágenes', value: role.cantidadImagenes),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          formatPesos(role.totalSuma),
                          style: textTheme.titleLarge
                              ?.merge(AppTypography.tabular)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        'Total',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (faltan > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: AppSpacing.lg,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        faltan == 1
                            ? 'Falta 1 imagen por registrar'
                            : 'Faltan $faltan imágenes por registrar',
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget block(double height) => Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.cardAll,
      ),
    );

    return AppShimmer(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          block(170),
          const SizedBox(height: AppSpacing.lg),
          block(110),
          const SizedBox(height: AppSpacing.sm),
          block(110),
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
