import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/l10n.dart';
import '../services/health_sync_service.dart';

/// Today's steps, last night's sleep and (when a watch or ring recorded
/// them) the latest resting heart rate and HRV from Apple Health / Health
/// Connect, on the Today dashboard. Hidden unless Health is connected with
/// "Activity on Home" on, and there's something to show.
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
        final restingHr = today.restingHeartRate == null ? l10n.nativeHealthNoData : l10n.nativeHealthBpm(today.restingHeartRate!);
        final hrv = today.hrvMs == null ? l10n.nativeHealthNoData : l10n.nativeHealthMs(today.hrvMs!);
        var semantics = l10n.nativeHealthTodaySemantics(steps, sleep);
        if (today.hasRecovery) semantics = '$semantics, ${l10n.nativeHealthRecoverySemantics(restingHr, hrv)}';
        return Semantics(
          container: true,
          label: semantics,
          child: ExcludeSemantics(
            child: Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: cs.surfaceContainerLow,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
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
                    if (today.hasRecovery) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _Stat(
                              icon: Icons.monitor_heart_outlined,
                              color: const Color(0xFFD9475B),
                              label: l10n.nativeHealthRestingHeartRate,
                              value: restingHr,
                              caption: l10n.nativeHealthLatest,
                            ),
                          ),
                          Container(width: 1, height: 44, color: cs.outlineVariant),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _Stat(
                              icon: Icons.insights_rounded,
                              color: const Color(0xFF2B87C8),
                              label: l10n.nativeHealthHrv,
                              value: hrv,
                              caption: l10n.nativeHealthLatest,
                            ),
                          ),
                        ],
                      ),
                    ],
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
