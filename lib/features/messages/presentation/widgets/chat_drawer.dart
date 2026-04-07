// lib/features/messages/presentation/widgets/chat_drawer.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatsapp_monitor_viewer/core/time/shifts.dart';
import 'package:whatsapp_monitor_viewer/features/messages/domain/entities/date_filter.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/date_filter_provider.dart';
import 'package:whatsapp_monitor_viewer/features/messages/presentation/providers/shift_stats_provider.dart';

class ChatDrawer extends ConsumerWidget {
  const ChatDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(dateFilterProvider);
    final notifier = ref.read(dateFilterProvider.notifier);
    final shiftStats = ref.watch(shiftStatsProvider);

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // ── Título principal ──
            Text(
              'Panel de control',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),

            // ══════════════════════════
            // SECCIÓN: Filtro de fecha
            // ══════════════════════════
            _SectionTitle(label: 'Filtrar por fecha'),
            const SizedBox(height: 8),
            _FilterOption(
              label: 'Hoy y ayer',
              icon: Icons.today,
              isSelected: filter is DateFilterTodayAndYesterday,
              onTap: () {
                notifier.setFilter(const DateFilterTodayAndYesterday());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Hoy',
              icon: Icons.wb_sunny_outlined,
              isSelected: filter is DateFilterToday,
              onTap: () {
                notifier.setFilter(const DateFilterToday());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Ayer',
              icon: Icons.history,
              isSelected: filter is DateFilterYesterday,
              onTap: () {
                notifier.setFilter(const DateFilterYesterday());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Esta semana',
              icon: Icons.date_range,
              isSelected: filter is DateFilterThisWeek,
              onTap: () {
                notifier.setFilter(const DateFilterThisWeek());
                Navigator.pop(context);
              },
            ),
            _FilterOption(
              label: 'Día específico…',
              icon: Icons.calendar_month,
              isSelected: filter is DateFilterSpecificDay,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: filter is DateFilterSpecificDay
                      ? filter.date
                      : DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null && context.mounted) {
                  notifier.setFilter(DateFilterSpecificDay(date: picked));
                  Navigator.pop(context);
                }
              },
            ),

            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),

            // ══════════════════════════
            // SECCIÓN: Imágenes por jornada
            // ══════════════════════════
            _SectionTitle(label: 'Imágenes por jornada'),
            const SizedBox(height: 4),
            Text(
              'Calculado sobre los mensajes cargados',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ...Shift.values.map(
              (shift) => _ShiftStatRow(
                label: shiftNames[shift]!,
                count: shiftStats[shift] ?? 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets internos ──────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: Colors.black54,
        letterSpacing: 0.4,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00897B).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ShiftStatRow extends StatelessWidget {
  final String label;
  final int count;

  const _ShiftStatRow({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    final hasImages = count > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: hasImages
            ? const Color(0xFF00897B).withValues(alpha: 0.06)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.image_outlined,
            size: 18,
            color: hasImages ? const Color(0xFF00897B) : Colors.grey,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: hasImages ? Colors.black87 : Colors.grey,
                fontWeight: hasImages ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: hasImages ? const Color(0xFF00897B) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
