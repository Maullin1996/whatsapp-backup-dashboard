// lib/features/messages/presentation/widgets/date_filter_bottom_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/date_filter_provider.dart';

class DateFilterBottomSheet extends ConsumerWidget {
  const DateFilterBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DateFilterBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(dateFilterProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Filtrar por fecha',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _FilterOption(
              label: 'Hoy y ayer',
              icon: Icons.today,
              isSelected: current is DateFilterTodayAndYesterday,
              onTap: () {
                ref
                    .read(dateFilterProvider.notifier)
                    .setFilter(const DateFilterTodayAndYesterday());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Hoy',
              icon: Icons.wb_sunny_outlined,
              isSelected: current is DateFilterToday,
              onTap: () {
                ref
                    .read(dateFilterProvider.notifier)
                    .setFilter(const DateFilterToday());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Ayer',
              icon: Icons.history,
              isSelected: current is DateFilterYesterday,
              onTap: () {
                ref
                    .read(dateFilterProvider.notifier)
                    .setFilter(const DateFilterYesterday());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Esta semana',
              icon: Icons.date_range,
              isSelected: current is DateFilterThisWeek,
              onTap: () {
                ref
                    .read(dateFilterProvider.notifier)
                    .setFilter(const DateFilterThisWeek());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Día específico…',
              icon: Icons.calendar_month,
              isSelected: current is DateFilterSpecificDay,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: current is DateFilterSpecificDay
                      ? current.date
                      : DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && context.mounted) {
                  ref
                      .read(dateFilterProvider.notifier)
                      .setFilter(DateFilterSpecificDay(date: picked));
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? const Color(0xFF00897B) : Colors.black87;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00897B).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
