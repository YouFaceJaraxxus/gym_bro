import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/wrapped.dart';
import '../../services/settings_service.dart';
import '../../theme.dart';
import '../../widgets/streak_widgets.dart';

/// The year on one card, story-shaped (9:16): the big numbers, the top
/// exercise and the badges. Laid out at [WrappedSummaryCard.size] and
/// scaled to fit; that's also the size it's rendered at for sharing.
class WrappedSummaryCard extends StatelessWidget {
  final Wrapped wrapped;

  /// "@username" in the corner.
  final String? handle;

  const WrappedSummaryCard({super.key, required this.wrapped, this.handle});

  static const size = Size(360, 640);

  static const gradient = [Color(0xFF2B0A57), Color(0xFF8A1E9B), Color(0xFFFF4D6D), Color(0xFFFFA43A)];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final w = wrapped;
    final settings = SettingsService.instance;
    final compact = NumberFormat.compact(locale: l10n.localeName);
    final whole = NumberFormat.decimalPattern(l10n.localeName);
    final hours = w.totals.hours;
    final top = w.topBySets.isEmpty ? null : w.topBySets.first;

    final stats = <(String, String)>[
      (l10n.wrappedSummaryWorkouts, whole.format(w.totals.workouts)),
      (l10n.wrappedSummaryHours, hours < 10 ? NumberFormat('0.#', l10n.localeName).format(hours) : whole.format(hours.round())),
      (l10n.wrappedSummaryVolume, '${compact.format(settings.toDisplayWeight(w.totals.volumeKg))} ${settings.weightUnit.value}'),
      (l10n.wrappedSummaryStreak, whole.format(w.longestStreak)),
      (l10n.wrappedSummaryPrs, whole.format(w.prCount)),
      (l10n.wrappedSummaryDays, whole.format(w.totals.activeDays)),
    ];

    return SizedBox.fromSize(
      size: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              stops: [0, 0.4, 0.75, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              const Positioned(right: -90, top: -60, child: _Glow(size: 260, color: Color(0xFFFF7AC6))),
              const Positioned(left: -80, bottom: 90, child: _Glow(size: 220, color: Color(0xFF6A5CFF))),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          l10n.wrappedTitle.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.6),
                        ),
                        const Spacer(),
                        if (handle != null)
                          Flexible(
                            child: Text(
                              handle!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${w.year}',
                      style: AppText.stat(size: 100, weight: FontWeight.w800, color: Colors.white, height: 0.95, letterSpacing: -2),
                    ),
                    Text(
                      l10n.wrappedSummaryKicker,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 20),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.9,
                      children: [for (final (label, value) in stats) _Stat(label: label, value: value)],
                    ),
                    const SizedBox(height: 14),
                    Expanded(child: _Months(byMonth: w.byMonth, best: w.bestMonth, locale: l10n.localeName)),
                    if (top != null) ...[
                      const SizedBox(height: 10),
                      _Row(icon: Icons.fitness_center_rounded, label: l10n.wrappedSummaryTop, value: top.name),
                    ],
                    if (w.badges.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          for (final b in w.badges.take(7))
                            Padding(padding: const EdgeInsets.only(right: 6), child: StreakGem(tier: b.tier, size: 24, shimmer: false)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.stat(size: 32, weight: FontWeight.w800, color: Colors.white, height: 1.1),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Workouts per month as a row of little bars, the best one lit.
class _Months extends StatelessWidget {
  final List<int> byMonth;
  final int? best;
  final String locale;

  const _Months({required this.byMonth, required this.best, required this.locale});

  @override
  Widget build(BuildContext context) {
    final most = byMonth.fold<int>(1, (a, b) => b > a ? b : a);
    final letter = DateFormat('MMMMM', locale);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var m = 1; m <= 12; m++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: m - 1 < byMonth.length ? (byMonth[m - 1] / most).clamp(0.06, 1.0) : 0.06,
                      child: Container(
                        decoration: BoxDecoration(
                          color: m == best ? Colors.white : Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    letter.format(DateTime(2024, m)).toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: m == best ? 1 : 0.65),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)]),
        ),
      );
}
