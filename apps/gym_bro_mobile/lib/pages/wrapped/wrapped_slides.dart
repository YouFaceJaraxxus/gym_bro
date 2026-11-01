import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/wrapped.dart';
import '../../services/settings_service.dart';
import '../../theme.dart';
import '../../widgets/challenge_medals.dart';
import '../../models/challenge.dart';
import '../../widgets/streak_widgets.dart';

// The slides of the Wrapped story. Each is drawn on its own bold gradient,
// with numbers counting up and lists arriving one by one; with animations
// off ([calm]) everything is simply there.

/// One slide: its background and what's on it.
class WrappedSlide {
  final String id;
  final List<Color> colors;
  final Widget Function(BuildContext context, bool calm) build;

  /// The last slide holds its own buttons and doesn't advance by itself.
  final bool isFinal;

  const WrappedSlide({required this.id, required this.colors, required this.build, this.isFinal = false});
}

const _intro = [Color(0xFF1A0B3D), Color(0xFF6A1B9A), Color(0xFFE91E63)];
const _workouts = [Color(0xFFFF6A00), Color(0xFFEE0979)];
const _volume = [Color(0xFF2B0B8F), Color(0xFF8E2DE2), Color(0xFFDA44BB)];
const _top = [Color(0xFF00695C), Color(0xFF0B8793), Color(0xFF2E3192)];
const _prs = [Color(0xFFFF8A00), Color(0xFFE52E71)];
const _rhythm = [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)];
const _gym = [Color(0xFFDA22FF), Color(0xFF9733EE), Color(0xFF3F2B96)];
const _streak = [Color(0xFFFF512F), Color(0xFFDD2476), Color(0xFF7B1FA2)];
const _empty = [Color(0xFF232526), Color(0xFF414345)];
const summaryColors = [Color(0xFF0B0F1F), Color(0xFF1B1F3B), Color(0xFF2A1442)];

/// The slides worth showing for [w]: empty sections are skipped.
List<WrappedSlide> buildWrappedSlides(Wrapped w, {required Widget Function(BuildContext, bool) summary}) {
  final slides = <WrappedSlide>[
    WrappedSlide(id: 'intro', colors: _intro, build: (c, calm) => _IntroSlide(year: w.year, calm: calm)),
  ];
  if (w.isEmpty) {
    slides.add(WrappedSlide(id: 'empty', colors: _empty, isFinal: true, build: (c, calm) => _EmptySlide(year: w.year)));
    return slides;
  }
  if (w.totals.workouts > 0) {
    slides.add(WrappedSlide(id: 'workouts', colors: _workouts, build: (c, calm) => _WorkoutsSlide(w: w, calm: calm)));
  }
  if (w.totals.volumeKg > 0) {
    slides.add(WrappedSlide(id: 'volume', colors: _volume, build: (c, calm) => _VolumeSlide(w: w, calm: calm)));
  }
  if (w.topBySets.isNotEmpty) {
    slides.add(WrappedSlide(id: 'top', colors: _top, build: (c, calm) => _TopSlide(w: w, calm: calm)));
  }
  if (w.prCount > 0 || w.bestLifts.isNotEmpty) {
    slides.add(WrappedSlide(id: 'prs', colors: _prs, build: (c, calm) => _PrSlide(w: w, calm: calm)));
  }
  if (w.totals.workouts > 0) {
    slides.add(WrappedSlide(id: 'rhythm', colors: _rhythm, build: (c, calm) => _RhythmSlide(w: w, calm: calm)));
  }
  if (w.hasGymSlide) {
    slides.add(WrappedSlide(id: 'gym', colors: _gym, build: (c, calm) => _GymSlide(w: w, calm: calm)));
  }
  if (w.hasStreakSlide) {
    slides.add(WrappedSlide(id: 'streak', colors: _streak, build: (c, calm) => _StreakSlide(w: w, calm: calm)));
  }
  slides.add(WrappedSlide(id: 'summary', colors: summaryColors, isFinal: true, build: summary));
  return slides;
}

// ── Building blocks ───────────────────────────────────────────────────────────

/// The gradient with big soft glows; [seed] moves them around per slide.
class WrappedBackdrop extends StatelessWidget {
  final List<Color> colors;
  final int seed;
  final Widget child;

  const WrappedBackdrop({super.key, required this.colors, this.seed = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    final r = math.Random(seed);
    double at() => r.nextDouble() * 2 - 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < 3; i++)
            Align(
              alignment: Alignment(at(), at()),
              child: FractionallySizedBox(
                widthFactor: 0.9 + r.nextDouble() * 0.5,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Colors.white.withValues(alpha: 0.13 - i * 0.03), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

const _white = Colors.white;
Color _soft([double a = 0.82]) => Colors.white.withValues(alpha: a);

TextStyle _kickerStyle(BuildContext context) =>
    TextStyle(color: _soft(0.9), fontSize: 20, fontWeight: FontWeight.w700, height: 1.25);

/// Poster numbers and headlines in the condensed display face.
TextStyle _hugeStyle(double size) => AppText.stat(
      size: size,
      weight: FontWeight.w800,
      color: _white,
      letterSpacing: -size * 0.01,
    );

/// Fades and lifts [child] in after [delay] ms.
Widget _enter(Widget child, bool calm, {int delay = 0, double dy = 0.25}) =>
    calm ? child : child.animate().fadeIn(delay: delay.ms, duration: 450.ms).slideY(begin: dy, end: 0, curve: Curves.easeOutCubic);

/// Fades and slides [child] in from the right after [delay] ms (staggered lists).
Widget _slideIn(Widget child, bool calm, {int delay = 0}) =>
    calm ? child : child.animate().fadeIn(delay: delay.ms, duration: 450.ms).slideX(begin: 0.18, end: 0, curve: Curves.easeOutCubic);

/// A number counting up from zero.
class WrappedCountUp extends StatelessWidget {
  final double value;
  final String Function(double) format;
  final TextStyle style;
  final bool calm;
  final int delay;

  const WrappedCountUp({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    required this.calm,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(format(value), style: style, maxLines: 1);
    if (calm) return FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: text);
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: const SizedBox().animate().custom(
            delay: delay.ms,
            duration: 1400.ms,
            curve: Curves.easeOutExpo,
            builder: (context, t, _) => Text(format(value * t), style: style, maxLines: 1),
          ),
    );
  }
}

class _SlideBody extends StatelessWidget {
  final List<Widget> children;

  const _SlideBody({required this.children});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        // Room for the segments on top and the Previous / Next buttons below.
        padding: const EdgeInsets.fromLTRB(28, 72, 28, 96),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: children),
      ),
    );
  }
}

NumberFormat _whole(AppLocalizations l10n) => NumberFormat.decimalPattern(l10n.localeName);

String _weight(double kg, {int decimals = 0}) => SettingsService.instance.formatWeight(kg, decimals: decimals);

// ── Slides ────────────────────────────────────────────────────────────────────

class _IntroSlide extends StatelessWidget {
  final int year;
  final bool calm;

  const _IntroSlide({required this.year, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget yearText = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFFD6E8), Color(0xFFFFC46B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(r),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text('$year', style: _hugeStyle(150).copyWith(letterSpacing: -3)),
      ),
    );
    if (!calm) {
      yearText = yearText
          .animate()
          .fadeIn(duration: 600.ms)
          .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), duration: 900.ms, curve: Curves.easeOutBack);
    }
    Widget hint = Row(
      children: [
        Icon(Icons.touch_app_rounded, color: _soft(0.7), size: 20),
        const SizedBox(width: 8),
        Text(l10n.wrappedIntroHint, style: TextStyle(color: _soft(0.7), fontWeight: FontWeight.w600)),
      ],
    );
    if (!calm) {
      hint = hint.animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(delay: 1200.ms, duration: 900.ms).then().fade(begin: 1, end: 0.4, duration: 900.ms);
    }
    return _SlideBody(
      children: [
        const Spacer(flex: 2),
        _enter(Text(l10n.wrappedIntroKicker.toUpperCase(), style: _kickerStyle(context).copyWith(fontSize: 15, letterSpacing: 2)), calm),
        const SizedBox(height: 8),
        yearText,
        _enter(
          Text(l10n.wrappedIntroWord, style: _hugeStyle(56).copyWith(fontStyle: FontStyle.italic, letterSpacing: -1)),
          calm,
          delay: 350,
        ),
        const Spacer(flex: 3),
        hint,
      ],
    );
  }
}

class _WorkoutsSlide extends StatelessWidget {
  final Wrapped w;
  final bool calm;

  const _WorkoutsSlide({required this.w, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hours = w.totals.hours;
    final hoursText = hours < 10 ? NumberFormat('0.#', l10n.localeName).format(hours) : _whole(l10n).format(hours.round());
    final first = w.firstWorkoutOn;
    return _SlideBody(
      children: [
        _enter(Text(l10n.wrappedWorkoutsKicker, style: _kickerStyle(context)), calm),
        const SizedBox(height: 12),
        WrappedCountUp(
          value: w.totals.workouts.toDouble(),
          format: (v) => _whole(l10n).format(v.round()),
          style: _hugeStyle(150),
          calm: calm,
          delay: 200,
        ),
        _enter(Text(l10n.wrappedWorkoutsUnit(w.totals.workouts), style: _hugeStyle(40)), calm, delay: 300),
        const SizedBox(height: 28),
        _enter(
          _Line(icon: Icons.calendar_month_rounded, text: l10n.wrappedActiveDays(w.totals.activeDays)),
          calm,
          delay: 1100,
        ),
        _enter(_Line(icon: Icons.timer_rounded, text: l10n.wrappedHours(hoursText)), calm, delay: 1300),
        if (first != null)
          _enter(
            _Line(icon: Icons.flag_rounded, text: l10n.wrappedFirstWorkout(DateFormat.MMMMd(l10n.localeName).format(first))),
            calm,
            delay: 1500,
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Line({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: _soft(0.18), shape: BoxShape.circle),
            child: Icon(icon, color: _white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: _white, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// "That's about 10 elephants": something as heavy as [kg].
String? volumeComparison(AppLocalizations l10n, double kg) {
  if (kg >= 12000) return l10n.wrappedVolumeElephants((kg / 6000).round());
  if (kg >= 3000) return l10n.wrappedVolumeCars((kg / 1500).round());
  if (kg >= 450) return l10n.wrappedVolumePianos((kg / 450).round());
  return null;
}

class _VolumeSlide extends StatelessWidget {
  final Wrapped w;
  final bool calm;

  const _VolumeSlide({required this.w, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = SettingsService.instance;
    final display = settings.toDisplayWeight(w.totals.volumeKg);
    final compare = volumeComparison(l10n, w.totals.volumeKg);
    return _SlideBody(
      children: [
        _enter(Text(l10n.wrappedVolumeKicker, style: _kickerStyle(context)), calm),
        const SizedBox(height: 12),
        WrappedCountUp(
          value: display,
          format: (v) => _whole(l10n).format(v.round()),
          style: _hugeStyle(110),
          calm: calm,
          delay: 200,
        ),
        _enter(Text(settings.weightUnit.value, style: _hugeStyle(48)), calm, delay: 300),
        const SizedBox(height: 28),
        if (compare != null)
          _enter(
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: _soft(0.16), borderRadius: BorderRadius.circular(18)),
              child: Text(compare, style: const TextStyle(color: _white, fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            calm,
            delay: 1300,
          ),
        const SizedBox(height: 16),
        _enter(
          Text(
            l10n.wrappedSetsReps(_whole(l10n).format(w.totals.sets), _whole(l10n).format(w.totals.reps)),
            style: TextStyle(color: _soft(), fontSize: 18, fontWeight: FontWeight.w700),
          ),
          calm,
          delay: 1500,
        ),
      ],
    );
  }
}

class _TopSlide extends StatelessWidget {
  final Wrapped w;
  final bool calm;

  const _TopSlide({required this.w, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = w.topBySets.take(5).toList();
    final most = top.map((e) => e.sets).fold<int>(1, math.max);
    return _SlideBody(
      children: [
        _enter(Text(l10n.wrappedTopKicker, style: _kickerStyle(context).copyWith(fontSize: 26, color: _white)), calm),
        const SizedBox(height: 28),
        for (final (i, e) in top.indexed)
          _slideIn(
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${i + 1}',
                      style: _hugeStyle(i == 0 ? 46 : 36).copyWith(color: i == 0 ? const Color(0xFFFFE066) : _soft(0.9)),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _white, fontSize: i == 0 ? 22 : 18, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, box) {
                                  final width = box.maxWidth * (e.sets / most).clamp(0.08, 1.0);
                                  Widget bar = Container(
                                    height: 8,
                                    width: width,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(colors: [Color(0xFFFFE066), Color(0xFF7CFFCB)]),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  );
                                  if (!calm) {
                                    bar = bar.animate().scaleX(
                                          begin: 0,
                                          end: 1,
                                          alignment: Alignment.centerLeft,
                                          delay: (450 + i * 160).ms,
                                          duration: 700.ms,
                                          curve: Curves.easeOutCubic,
                                        );
                                  }
                                  return Align(alignment: Alignment.centerLeft, child: bar);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              l10n.wrappedTopSets(e.sets),
                              style: TextStyle(color: _soft(), fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            calm,
            delay: 300 + i * 160,
          ),
      ],
    );
  }
}

class _PrSlide extends StatelessWidget {
  final Wrapped w;
  final bool calm;

  const _PrSlide({required this.w, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lifts = w.bestLifts.take(4).toList();
    return _SlideBody(
      children: [
        _enter(Text(l10n.wrappedPrKicker, style: _kickerStyle(context)), calm),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (w.prCount > 0)
              Flexible(
                child: WrappedCountUp(
                  value: w.prCount.toDouble(),
                  format: (v) => _whole(l10n).format(v.round()),
                  style: _hugeStyle(130),
                  calm: calm,
                  delay: 200,
                ),
              ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _enter(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.wrappedPrCount(w.prCount), style: _hugeStyle(w.prCount > 0 ? 30 : 34)),
                    const SizedBox(width: 6),
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFE066), size: 34),
                  ],
                ),
                calm,
                delay: 300,
              ),
            ),
          ],
        ),
        if (lifts.isNotEmpty) ...[
          const SizedBox(height: 28),
          _enter(Text(l10n.wrappedBestLifts, style: TextStyle(color: _soft(), fontSize: 15, fontWeight: FontWeight.w700)), calm, delay: 900),
          const SizedBox(height: 12),
          for (final (i, lift) in lifts.indexed)
            _enter(
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lift.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          if (lift.weightKg != null && lift.reps != null)
                            Text(
                              l10n.wrappedLiftDetail(_weight(lift.weightKg!, decimals: 1), lift.reps!),
                              style: TextStyle(color: _soft(0.75), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _weight(lift.e1rm, decimals: 1),
                      style: AppText.stat(size: 24, weight: FontWeight.w800, color: _white),
                    ),
                  ],
                ),
              ),
              calm,
              delay: 1050 + i * 140,
            ),
        ],
      ],
    );
  }
}

class _RhythmSlide extends StatelessWidget {
  final Wrapped w;
  final bool calm;

  const _RhythmSlide({required this.w, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = l10n.localeName;
    // 2024-01-01 was a Monday.
    DateTime weekday(int isoDow) => DateTime(2024, 1, isoDow);
    final busiest = w.busiestWeekday;
    final most = w.byWeekday.fold<int>(1, math.max);
    final hour = w.favouriteHour;
    final month = w.bestMonth;
    return _SlideBody(
      children: [
        _enter(Text(l10n.wrappedRhythmKicker, style: _kickerStyle(context)), calm),
        const SizedBox(height: 10),
        if (busiest != null)
          _enter(
            Text(
              l10n.wrappedBusiestDay(_title(DateFormat.EEEE(locale).format(weekday(busiest)))),
              style: _hugeStyle(42).copyWith(height: 1.1, letterSpacing: -1),
            ),
            calm,
            delay: 150,
          ),
        const SizedBox(height: 28),
        SizedBox(
          height: 170,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var d = 1; d <= 7; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${w.byWeekday[d - 1]}',
                          style: TextStyle(color: d == busiest ? _white : _soft(0.6), fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        _Bar(
                          fraction: w.byWeekday[d - 1] / most,
                          highlight: d == busiest,
                          calm: calm,
                          delay: 300 + d * 70,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat.E(locale).format(weekday(d)).substring(0, 1).toUpperCase(),
                          style: TextStyle(color: d == busiest ? _white : _soft(0.6), fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        if (hour != null)
          _enter(
            _Line(icon: Icons.schedule_rounded, text: l10n.wrappedFavouriteHour(DateFormat.j(locale).format(DateTime(2024, 1, 1, hour)))),
            calm,
            delay: 1000,
          ),
        if (month != null)
          _enter(
            _Line(
              icon: Icons.bolt_rounded,
              text: l10n.wrappedBestMonth(_title(DateFormat.MMMM(locale).format(DateTime(2024, month))), w.byMonth[month - 1]),
            ),
            calm,
            delay: 1200,
          ),
      ],
    );
  }
}

String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Bar extends StatelessWidget {
  final double fraction;
  final bool highlight;
  final bool calm;
  final int delay;

  const _Bar({required this.fraction, required this.highlight, required this.calm, required this.delay});

  @override
  Widget build(BuildContext context) {
    Widget bar = Container(
      height: 110 * fraction.clamp(0.04, 1.0),
      decoration: BoxDecoration(
        gradient: highlight
            ? const LinearGradient(colors: [Color(0xFF7CFFCB), Color(0xFF00C6FF)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
            : null,
        color: highlight ? null : _soft(0.28),
        borderRadius: BorderRadius.circular(8),
      ),
    );
    if (!calm) {
      bar = bar.animate().scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, delay: delay.ms, duration: 600.ms, curve: Curves.easeOutBack);
    }
    return bar;
  }
}

class _GymSlide extends StatelessWidget {
  final Wrapped w;
  final bool calm;

  const _GymSlide({required this.w, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gym = w.favouriteGym;
    return _SlideBody(
      children: [
        _enter(Text(l10n.wrappedGymKicker, style: _kickerStyle(context)), calm),
        const SizedBox(height: 8),
        if (w.checkIns > 0) ...[
          WrappedCountUp(
            value: w.checkIns.toDouble(),
            format: (v) => _whole(l10n).format(v.round()),
            style: _hugeStyle(140),
            calm: calm,
            delay: 200,
          ),
          _enter(Text(l10n.wrappedCheckIns(w.checkIns), style: _hugeStyle(40)), calm, delay: 300),
        ],
        const SizedBox(height: 32),
        if (gym != null)
          _enter(
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _soft(0.14),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _soft(0.22)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(color: _white, shape: BoxShape.circle),
                    child: const Icon(Icons.home_rounded, color: Color(0xFF9733EE), size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.wrappedFavouriteGym, style: TextStyle(color: _soft(0.8), fontWeight: FontWeight.w700)),
                        Text(gym.name, style: const TextStyle(color: _white, fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            calm,
            delay: 1100,
          ),
        if (w.classesAttended > 0) ...[
          const SizedBox(height: 16),
          _enter(_Line(icon: Icons.groups_rounded, text: l10n.wrappedClasses(w.classesAttended)), calm, delay: 1300),
        ],
      ],
    );
  }
}

class _StreakSlide extends StatelessWidget {
  final Wrapped w;
  final bool calm;

  const _StreakSlide({required this.w, required this.calm});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget flame = const StreakFlame(size: 84);
    if (!calm) {
      flame = flame
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(0.94, 0.94), end: const Offset(1.06, 1.06), duration: 900.ms, curve: Curves.easeInOut);
    }
    return _SlideBody(
      children: [
        _enter(Text(l10n.wrappedStreakKicker, style: _kickerStyle(context)), calm),
        const SizedBox(height: 16),
        if (w.longestStreak > 0) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              flame,
              const SizedBox(width: 8),
              Expanded(
                child: WrappedCountUp(
                  value: w.longestStreak.toDouble(),
                  format: (v) => _whole(l10n).format(v.round()),
                  style: _hugeStyle(120),
                  calm: calm,
                  delay: 200,
                ),
              ),
            ],
          ),
          _enter(
            Text('${l10n.wrappedLongestStreak} · ${l10n.wrappedInARow(w.longestStreak)}', style: _hugeStyle(22).copyWith(height: 1.2)),
            calm,
            delay: 300,
          ),
        ],
        if (w.badges.isNotEmpty) ...[
          const SizedBox(height: 32),
          _enter(Text(l10n.wrappedBadges, style: TextStyle(color: _soft(), fontSize: 15, fontWeight: FontWeight.w700)), calm, delay: 900),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (i, b) in w.badges.indexed)
                calm
                    ? StreakGem(tier: b.tier, size: 46)
                    : StreakGem(tier: b.tier, size: 46, shimmer: true)
                        .animate()
                        .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          delay: (1000 + i * 150).ms,
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        ),
            ],
          ),
        ],
        if (w.challenges.isNotEmpty) ...[
          const SizedBox(height: 28),
          _enter(
            Row(
              children: [
                for (final _ in w.challenges.take(4))
                  const Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: ChallengeMedalIcon(metric: ChallengeMetric.workouts, size: 40),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.wrappedChallenges(w.challenges.length),
                    style: const TextStyle(color: _white, fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            calm,
            delay: 1400,
          ),
        ],
      ],
    );
  }
}

class _EmptySlide extends StatelessWidget {
  final int year;

  const _EmptySlide({required this.year});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _SlideBody(
      children: [
        Icon(Icons.bedtime_rounded, color: _soft(0.9), size: 64),
        const SizedBox(height: 20),
        Text(l10n.wrappedEmptyTitle, style: _hugeStyle(48).copyWith(letterSpacing: -1)),
        const SizedBox(height: 12),
        Text(l10n.wrappedEmptyBody('$year'), style: TextStyle(color: _soft(), fontSize: 18, fontWeight: FontWeight.w600, height: 1.35)),
        const SizedBox(height: 32),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _white, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(52)),
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(l10n.wrappedDone),
        ),
      ],
    );
  }
}
