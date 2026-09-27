import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:whatsapp_monitor_viewer/core/responsive/responsive_layout.dart';
import 'package:whatsapp_monitor_viewer/core/theme/theme.dart';

/// Resumen de reportes por jornada. Por ahora solo el punto de entrada
/// (menú + ruta): sin datos ni lógica de negocio.
class SummaryPage extends ConsumerWidget {
  const SummaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: reemplazar por la reconciliación real (paso 5 del feature de
    // revisión de imágenes, ver image-review-workflow).
    return const ResponsiveLayout(
      mobile: _SummaryScaffold(
        titleStyle: AppTypography.adminAppBarTitle,
        body: _SummaryEmptyState(),
      ),
      desktop: _SummaryScaffold(
        titleStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
        ),
        body: _SummaryEmptyState(),
      ),
    );
  }
}

class _SummaryScaffold extends StatelessWidget {
  final TextStyle titleStyle;
  final Widget body;

  const _SummaryScaffold({required this.titleStyle, required this.body});

  @override
  Widget build(BuildContext context) {
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
      ),
      backgroundColor: Colors.white,
      body: body,
    );
  }
}

class _SummaryEmptyState extends StatelessWidget {
  const _SummaryEmptyState();

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
              Icon(
                Icons.fact_check_rounded,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Todavía no hay reportes para mostrar',
                textAlign: TextAlign.center,
                style: AppTypography.headerTitle(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
