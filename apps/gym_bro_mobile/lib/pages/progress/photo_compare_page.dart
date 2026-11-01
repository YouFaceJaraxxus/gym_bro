import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/settings_service.dart';
import '../../utils/weight_trend.dart' show calendarDaysBetween;
import '../../widgets/app_bottom_sheet.dart';
import 'body_metric_labels.dart';
import 'progress_photo_widgets.dart';

/// Before/after: drag the divider to wipe between two photos. Any two can be
/// picked; by default the oldest and newest of the same pose.
class PhotoComparePage extends StatefulWidget {
  final List<ProgressPhoto> photos;
  final ProgressPhoto? before;
  final ProgressPhoto? after;

  const PhotoComparePage({super.key, required this.photos, this.before, this.after});

  @override
  State<PhotoComparePage> createState() => _PhotoComparePageState();
}

class _PhotoComparePageState extends State<PhotoComparePage> {
  late ProgressPhoto _before;
  late ProgressPhoto _after;

  @override
  void initState() {
    super.initState();
    final pair = defaultComparePair(widget.photos);
    _before = widget.before ?? pair?.before ?? widget.photos.first;
    _after = widget.after ?? pair?.after ?? widget.photos.last;
  }

  Future<void> _pick({required bool before}) async {
    final current = before ? _before : _after;
    final picked = await showAppBottomSheet<ProgressPhoto>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _PhotoPickerSheet(
        photos: widget.photos,
        selected: current,
        title: before ? ctx.l10n.bodyCompareBefore : ctx.l10n.bodyCompareAfter,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => before ? _before = picked : _after = picked);
  }

  void _swap() => setState(() {
    final b = _before;
    _before = _after;
    _after = b;
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final settings = SettingsService.instance;
    final days = calendarDaysBetween(_before.takenOn, _after.takenOn).abs();
    final change = _before.weightKg != null && _after.weightKg != null ? _after.weightKg! - _before.weightKg! : null;
    final span = days < 14 ? l10n.bodyCompareDays(days) : l10n.bodyCompareWeeks((days / 7).round());

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.bodyCompareTitle),
        actions: [
          IconButton(tooltip: l10n.bodyCompareSwap, icon: const Icon(Icons.swap_horiz), onPressed: _swap),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: PhotoCompareSlider(
                  key: ValueKey('${_before.id}-${_after.id}'),
                  before: _before,
                  after: _after,
                  beforeLabel: l10n.bodyCompareBefore,
                  afterLabel: l10n.bodyCompareAfter,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                change == null
                    ? span
                    : l10n.bodyCompareDiff('${change < 0 ? '−' : '+'}${settings.formatWeight(change.abs())}', span),
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PickCard(label: l10n.bodyCompareBefore, photo: _before, onTap: () => _pick(before: true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PickCard(label: l10n.bodyCompareAfter, photo: _after, onTap: () => _pick(before: false)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 14, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(l10n.bodyPhotosPrivate, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Two photos stacked; [before] shows left of a draggable vertical divider,
/// [after] right of it. Tap or drag anywhere to move the divider.
class PhotoCompareSlider extends StatefulWidget {
  final ProgressPhoto before;
  final ProgressPhoto after;
  final String beforeLabel;
  final String afterLabel;
  final double initial;

  const PhotoCompareSlider({
    super.key,
    required this.before,
    required this.after,
    required this.beforeLabel,
    required this.afterLabel,
    this.initial = 0.5,
  });

  @override
  State<PhotoCompareSlider> createState() => _PhotoCompareSliderState();
}

class _PhotoCompareSliderState extends State<PhotoCompareSlider> {
  late double _pos = widget.initial;

  void _moveTo(double dx, double width) {
    final next = (dx / width).clamp(0.0, 1.0);
    if (next != _pos) setState(() => _pos = next);
  }

  void _nudge(double by) {
    setState(() => _pos = (_pos + by).clamp(0.0, 1.0));
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final x = _pos * w;
        return Semantics(
          slider: true,
          label: l10n.bodyCompareSliderLabel,
          value: '${(_pos * 100).round()}%',
          increasedValue: '${((_pos + 0.1).clamp(0.0, 1.0) * 100).round()}%',
          decreasedValue: '${((_pos - 0.1).clamp(0.0, 1.0) * 100).round()}%',
          onIncrease: () => _nudge(0.1),
          onDecrease: () => _nudge(-0.1),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _moveTo(d.localPosition.dx, w),
            onHorizontalDragStart: (d) => _moveTo(d.localPosition.dx, w),
            onHorizontalDragUpdate: (d) => _moveTo(d.localPosition.dx, w),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: Colors.black, child: ProgressPhotoImage(photo: widget.after)),
                ClipRect(
                  clipper: _LeftOf(x),
                  child: ColoredBox(color: Colors.black, child: ProgressPhotoImage(photo: widget.before)),
                ),
                // Divider + knob.
                Positioned(
                  left: x - 1.5,
                  top: 0,
                  bottom: 0,
                  width: 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 6)],
                    ),
                  ),
                ),
                Positioned(
                  left: x - 22,
                  top: h / 2 - 22,
                  width: 44,
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
                    ),
                    child: const Icon(Icons.code, color: Colors.black87, size: 22),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  right: w / 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CornerLabel(
                      title: widget.beforeLabel,
                      detail: _detail(widget.before, l10n, locale),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  left: w / 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _CornerLabel(
                      title: widget.afterLabel,
                      detail: _detail(widget.after, l10n, locale),
                      end: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _detail(ProgressPhoto p, AppLocalizations l10n, String locale) => [
    DateFormat.yMMMd(locale).format(p.takenOn),
    if (p.weightKg != null) SettingsService.instance.formatWeight(p.weightKg!),
  ].join('\n');
}

class _LeftOf extends CustomClipper<Rect> {
  final double x;
  const _LeftOf(this.x);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, x.clamp(0, size.width), size.height);

  @override
  bool shouldReclip(_LeftOf old) => old.x != x;
}

class _CornerLabel extends StatelessWidget {
  final String title;
  final String detail;
  final bool end;

  const _CornerLabel({required this.title, required this.detail, this.end = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
          Text(
            detail,
            textAlign: end ? TextAlign.end : TextAlign.start,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _PickCard extends StatelessWidget {
  final String label;
  final ProgressPhoto photo;
  final VoidCallback onTap;

  const _PickCard({required this.label, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(width: 44, height: 58, child: ProgressPhotoImage(photo: photo)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: text.labelMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                    Text(
                      DateFormat.yMMMd(locale).format(photo.takenOn),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium,
                    ),
                    Text(
                      [
                        progressPoseLabel(photo.pose, l10n),
                        if (photo.weightKg != null) SettingsService.instance.formatWeight(photo.weightKg!),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.unfold_more, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPickerSheet extends StatelessWidget {
  final List<ProgressPhoto> photos;
  final ProgressPhoto selected;
  final String title;

  const _PhotoPickerSheet({required this.photos, required this.selected, required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final sorted = [...photos]..sort(compareProgressPhotosNewestFirst);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(l10n.bodyComparePick(title), style: text.titleLarge),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 3 / 4,
              ),
              itemCount: sorted.length,
              itemBuilder: (context, i) {
                final p = sorted[i];
                final isSelected = p.id == selected.id;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: progressPhotoCaption(p, l10n, locale),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, p),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ProgressPhotoImage(photo: p),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            right: 6,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: ProgressPhotoBadge(label: DateFormat.MMMd(locale).format(p.takenOn)),
                            ),
                          ),
                          if (isSelected)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.primary, width: 3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
