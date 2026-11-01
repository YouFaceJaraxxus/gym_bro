import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../services/health_sync_service.dart';

/// Today's steps and last night's sleep from Apple Health / Health Connect,
/// on the Today dashboard. Hidden unless Health is connected with "Steps and
/// sleep on Home" on, and there's something to show.
class HealthTodayCard extends StatefulWidget {
  const HealthTodayCard({super.key});

  @override
  State<HealthTodayCard> createState() => _HealthTodayCardState();
}

class _HealthTodayCardState extends State<HealthTodayCard> {
  final _health = HealthSyncService.instance;

  @override
  void initState() {
    super.initState();
    // Home is the first screen after signing in: weigh-ins when due, today.
    _health.syncIfDue();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HealthToday?>(
      valueListenable: _health.today,
      builder: (context, today, _) {
        if (today == null || today.isEmpty || !_health.isConnected || !_health.settings.value.showActivity) {
          return const SizedBox.shrink();
        }
        final l10n = context.l10n;
        final cs = Theme.of(context).colorScheme;
        final locale = Localizations.localeOf(context).toString();
        final steps = today.steps == null ? l10n.nativeHealthNoData : NumberFormat.decimalPattern(locale).format(today.steps);
        final minutes = today.sleepMinutes;
        final sleep = minutes == null ? l10n.nativeHealthNoData : l10n.nativeHealthSleepDuration(minutes ~/ 60, minutes % 60);
        return Semantics(
          container: true,
          label: l10n.nativeHealthTodaySemantics(steps, sleep),
          child: ExcludeSemantics(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        icon: Icons.directions_walk_rounded,
                        color: const Color(0xFF2E9D5B),
                        label: l10n.nativeHealthSteps,
                        value: steps,
                        caption: l10n.nativeHealthStepsToday,
                      ),
                    ),
                    Container(width: 1, height: 44, color: cs.outlineVariant),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _Stat(
                        icon: Icons.bedtime_rounded,
                        color: const Color(0xFF6F5BD8),
                        label: l10n.nativeHealthSleep,
                        value: sleep,
                        caption: l10n.nativeHealthSleepLastNight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.label, required this.value, required this.caption});

  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: text.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
