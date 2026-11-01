import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../l10n/l10n.dart';
import '../models/wrapped.dart';
import '../pages/wrapped/wrapped_page.dart';
import '../pages/wrapped/wrapped_views.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../utils/device_timezone.dart';

/// "Your 2026 in training is ready": opens Gym Bro Wrapped. Self-contained:
/// it asks GET /wrapped which years are open and shows itself only when
/// there's one to offer (this year from December 1, or a past year with a
/// recap not yet watched on this device); otherwise it takes no space.
/// [padding] goes around it when shown.
class WrappedBanner extends StatefulWidget {
  final EdgeInsetsGeometry padding;

  const WrappedBanner({super.key, this.padding = EdgeInsets.zero});

  @override
  State<WrappedBanner> createState() => _WrappedBannerState();
}

class _WrappedBannerState extends State<WrappedBanner> {
  WrappedIndex? _index;
  Set<int> _viewed = const {};

  @override
  void initState() {
    super.initState();
    _load();
    WrappedViews.changes.addListener(_loadViewed);
  }

  @override
  void dispose() {
    WrappedViews.changes.removeListener(_loadViewed);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        ApiService().getWrappedIndex(token, tz: await deviceTimezone()),
        WrappedViews.viewed(),
      ]);
      if (!mounted) return;
      setState(() {
        _index = results[0] as WrappedIndex;
        _viewed = results[1] as Set<int>;
      });
    } catch (_) {
      // No banner; Wrapped is still reachable from its notification.
    }
  }

  Future<void> _loadViewed() async {
    final viewed = await WrappedViews.viewed();
    if (mounted) setState(() => _viewed = viewed);
  }

  @override
  Widget build(BuildContext context) {
    final year = _index?.bannerYear(_viewed);
    if (year == null) return const SizedBox.shrink();
    return Padding(
      padding: widget.padding,
      child: WrappedBannerCard(
        year: year,
        onTap: () => Navigator.push(context, MaterialPageRoute(fullscreenDialog: true, builder: (_) => WrappedPage(year: year))),
      ),
    );
  }
}

/// The banner's look, without the loading (also used by tests).
class WrappedBannerCard extends StatelessWidget {
  final int year;
  final VoidCallback onTap;

  const WrappedBannerCard({super.key, required this.year, required this.onTap});

  static const _colors = [Color(0xFF2B0A57), Color(0xFF8A1E9B), Color(0xFFFF4D6D), Color(0xFFFFA43A)];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calm = MediaQuery.disableAnimationsOf(context);
    Widget yearText = Text(
      '$year',
      style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 0.9, letterSpacing: -3),
    );
    if (!calm) {
      yearText = yearText
          .animate(onPlay: (c) => c.repeat())
          .shimmer(delay: 2400.ms, duration: 1600.ms, color: const Color(0xFFFFE3A1));
    }
    final card = Semantics(
      button: true,
      label: '${l10n.wrappedBannerKicker}. ${l10n.wrappedBannerTitle('$year')}',
      excludeSemantics: true,
      child: Material(
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: _colors, stops: [0, 0.4, 0.75, 1], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -50,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    l10n.wrappedBannerKicker.toUpperCase(),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.wrappedBannerTitle('$year'),
                              style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.wrappedBannerBody,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l10n.wrappedBannerCta,
                                    style: const TextStyle(color: Color(0xFF2B0A57), fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.play_arrow_rounded, color: Color(0xFF2B0A57), size: 18),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      yearText,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (calm) return card;
    return card.animate().fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
  }
}
