import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/wrapped.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../utils/device_timezone.dart';
import 'wrapped_share.dart';
import 'wrapped_slides.dart';
import 'wrapped_summary_card.dart';
import 'wrapped_views.dart';

/// Gym Bro Wrapped for [year]: loads the recap and plays it as a story.
/// [preview] opens the current year before December (super users only).
class WrappedPage extends StatefulWidget {
  final int year;
  final bool preview;

  /// Skips loading (tests and previews).
  final Wrapped? initial;

  const WrappedPage({super.key, required this.year, this.preview = false, this.initial});

  @override
  State<WrappedPage> createState() => _WrappedPageState();
}

class _WrappedPageState extends State<WrappedPage> {
  Wrapped? _w;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _w = widget.initial;
    if (_w == null) _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final w = await ApiService().getWrapped(token, widget.year, tz: await deviceTimezone(), preview: widget.preview);
      if (w.available) await WrappedViews.markViewed(w.year);
      if (mounted) setState(() => _w = w);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = _w;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: w != null && w.available
            ? WrappedStory(wrapped: w)
            : WrappedBackdrop(
                colors: const [Color(0xFF1A0B3D), Color(0xFF6A1B9A), Color(0xFFE91E63)],
                child: SafeArea(
                  child: Stack(
                    children: [
                      Center(child: w == null && _error == null ? const CircularProgressIndicator(color: Colors.white) : _message(w)),
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          tooltip: context.l10n.wrappedClose,
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _message(Wrapped? w) {
    final l10n = context.l10n;
    final from = w?.availableFrom;
    final text = _error != null
        ? l10n.wrappedLoadFailed
        : w?.reason == 'not_yet' && from != null
            ? l10n.wrappedNotYet('${widget.year}', DateFormat.yMMMMd(l10n.localeName).format(from))
            : l10n.wrappedNoData('${widget.year}');
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_error != null ? Icons.cloud_off_rounded : Icons.auto_awesome_rounded, color: Colors.white, size: 56),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.3),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
              onPressed: _load,
              child: Text(l10n.wrappedRetry),
            ),
          ],
        ],
      ),
    );
  }
}

/// The story: progress segments on top, a slide at a time. Tap the right
/// side for the next one, the left for the previous, hold to pause. Slides
/// advance on their own unless animations are off or a screen reader is on
/// (then there are Previous / Next buttons instead).
class WrappedStory extends StatefulWidget {
  final Wrapped wrapped;

  const WrappedStory({super.key, required this.wrapped});

  static const slideDuration = Duration(seconds: 7);

  @override
  State<WrappedStory> createState() => _WrappedStoryState();
}

class _WrappedStoryState extends State<WrappedStory> with SingleTickerProviderStateMixin {
  late final AnimationController _progress;
  late List<WrappedSlide> _slides;
  final _cardKey = GlobalKey();
  int _index = 0;
  bool _sharing = false;

  /// Auto-advance; off with reduced motion or a screen reader.
  bool _auto = true;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _slides = buildWrappedSlides(widget.wrapped, summary: _summary);
    _progress = AnimationController(vsync: this, duration: WrappedStory.slideDuration)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _next();
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auto = !MediaQuery.disableAnimationsOf(context) && !MediaQuery.accessibleNavigationOf(context);
    if (!_started || auto != _auto) {
      _started = true;
      _auto = auto;
      _restart();
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  void _restart() {
    _progress.stop();
    if (_slides[_index].isFinal) {
      _progress.value = 1;
    } else if (_auto) {
      _progress.forward(from: 0);
    } else {
      _progress.value = 0;
    }
  }

  void _go(int to) {
    if (to < 0 || to >= _slides.length) return;
    HapticFeedback.selectionClick();
    setState(() => _index = to);
    _restart();
  }

  void _next() {
    if (!_isLast) _go(_index + 1);
  }

  void _previous() => _index == 0 ? _restart() : _go(_index - 1);

  void _pause() {
    if (_progress.isAnimating) _progress.stop();
  }

  void _resume() {
    if (_auto && !_slides[_index].isFinal && !_progress.isAnimating) _progress.forward();
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await shareWrappedCard(context, _cardKey, year: widget.wrapped.year);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _summary(BuildContext context, bool calm) {
    final l10n = context.l10n;
    final handle = AuthManager.instance.profile?.username;
    Widget card = FittedBox(
      child: RepaintBoundary(
        key: _cardKey,
        child: WrappedSummaryCard(wrapped: widget.wrapped, handle: handle == null || handle.isEmpty ? null : '@$handle'),
      ),
    );
    if (!calm) {
      card = card
          .animate()
          .fadeIn(duration: 500.ms)
          .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 700.ms, curve: Curves.easeOutBack);
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
        child: Column(
          children: [
            Expanded(child: Center(child: card)),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(54),
                textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.ios_share_rounded),
              label: Text(l10n.wrappedShare),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
              child: Text(l10n.wrappedDone),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calm = MediaQuery.disableAnimationsOf(context);
    final slide = _slides[_index];
    final width = MediaQuery.sizeOf(context).width;

    final content = KeyedSubtree(
      key: ValueKey(slide.id),
      child: WrappedBackdrop(
        colors: slide.colors,
        seed: _index * 7 + 3,
        child: Semantics(
          label: l10n.wrappedSlideLabel(_index + 1, _slides.length),
          child: slide.build(context, calm),
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => d.localPosition.dx < width * 0.3 ? _previous() : _next(),
          onLongPressStart: (_) => _pause(),
          onLongPressEnd: (_) => _resume(),
          child: AnimatedSwitcher(
            duration: calm ? Duration.zero : const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOut,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: child),
            ),
            child: content,
          ),
        ),
        // Segments and close.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _Segment(
                            value: i < _index ? null : (i == _index ? _progress : null),
                            filled: i < _index,
                          ),
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    const SizedBox(width: 6),
                    const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${l10n.wrappedTitle} ${widget.wrapped.year}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.wrappedClose,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!_auto && !slide.isFinal)
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filled(
                      tooltip: l10n.wrappedPrevious,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                        disabledForegroundColor: Colors.white38,
                      ),
                      onPressed: _index == 0 ? null : _previous,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    IconButton.filled(
                      tooltip: l10n.wrappedNext,
                      style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                      onPressed: _next,
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One progress segment: full, empty, or following [value].
class _Segment extends StatelessWidget {
  final Animation<double>? value;
  final bool filled;

  const _Segment({this.value, this.filled = false});

  @override
  Widget build(BuildContext context) {
    Widget bar(double v) => ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: v,
            minHeight: 3,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            color: Colors.white,
          ),
        );
    final a = value;
    if (a == null) return bar(filled ? 1 : 0);
    return AnimatedBuilder(animation: a, builder: (context, _) => bar(a.value));
  }
}
