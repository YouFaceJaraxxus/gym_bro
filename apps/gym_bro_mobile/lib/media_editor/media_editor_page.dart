import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../widgets/social_widgets.dart' show formatDuration;
import 'edited_media_view.dart';
import 'editable_media.dart';
import 'media_edit.dart';
import 'trim_timeline.dart';

enum _Tab { filter, adjust, trim }

/// Instagram-style editor for picked photos and videos: filters (with
/// strength), adjustments and, for videos, a trim with a live preview.
///
/// Edits are written to the [EditableMedia] as they're made, so leaving the
/// editor — back or Done — keeps them, and reopening it picks up where it
/// was, undo history included. Every setting has its own Undo and Reset.
///
/// "Edit all" ([editAll]) applies one filter and one set of adjustments to
/// every item (no per-item looks there); videos can still be trimmed one by
/// one.
class MediaEditorPage extends StatefulWidget {
  const MediaEditorPage._({required this.items, required this.batch, this.initialIndex = 0, this.groupHistory});

  final List<EditableMedia> items;
  final bool batch;
  final int initialIndex;
  final EditHistory? groupHistory;

  /// Edits one photo or video.
  static Future<void> edit(BuildContext context, EditableMedia item) => Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => MediaEditorPage._(items: [item], batch: false)),
  );

  /// Edits several together. Pass the same [history] each time to keep the
  /// group's undo steps between visits.
  static Future<void> editAll(BuildContext context, List<EditableMedia> items, {EditHistory? history, int initialIndex = 0}) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => MediaEditorPage._(items: items, batch: true, initialIndex: initialIndex, groupHistory: history),
        ),
      );

  @override
  State<MediaEditorPage> createState() => _MediaEditorPageState();
}

class _MediaEditorPageState extends State<MediaEditorPage> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;
  _Tab _tab = _Tab.filter;
  Adjustment? _tool;
  bool _comparing = false;

  /// Batch mode: the look shared by every item.
  late MediaEdit _group;
  late final EditHistory _groupHistory = widget.groupHistory ?? EditHistory();

  /// The edit when a slider / trim drag started, recorded for undo on release.
  MediaEdit? _dragStart;

  final Map<EditableMedia, TrimmedVideoController> _videos = {};

  @override
  void initState() {
    super.initState();
    final first = widget.items.first.edit;
    // Start from the items' shared look; if they differ, from scratch.
    _group = widget.items.every((m) => m.edit.sameLook(first)) ? MediaEdit.none.withLookOf(first) : MediaEdit.none;
  }

  @override
  void dispose() {
    for (final c in _videos.values) {
      c.dispose();
    }
    _pages.dispose();
    super.dispose();
  }

  EditableMedia get _current => widget.items[_index];
  bool get _hasVideo => widget.items.any((m) => m.isVideo);

  // ── Look (filter + adjustments) ─────────────────────────────────────────────

  MediaEdit get _look => widget.batch ? _group : _current.edit;
  EditHistory get _lookHistory => widget.batch ? _groupHistory : _current.history;

  void _setLook(MediaEdit next) {
    setState(() {
      if (widget.batch) {
        _group = next;
        for (final m in widget.items) {
          if (m.canEdit) m.edit = m.edit.withLookOf(next);
        }
      } else {
        _current.edit = next;
      }
    });
  }

  void _changeLook(EditSetting s, MediaEdit next) {
    _lookHistory.record(s, _look, next);
    _setLook(next);
  }

  void _undoLook(EditSetting s) => _setLook(_lookHistory.undo(s, _look));
  void _resetLook(EditSetting s) => _changeLook(s, EditHistory.reset(s, _look));

  // ── Trim (per video) ────────────────────────────────────────────────────────

  TrimmedVideoController _videoFor(EditableMedia m) => _videos.putIfAbsent(m, () {
    final c = TrimmedVideoController(m.original.file);
    c.initialize(start: m.edit.trimStart, end: m.edit.trimEnd).then((_) {
      if (mounted && m == _current) c.play();
    });
    return c;
  });

  /// Stores a trim, dropping a start at 0 and an end at the video's end.
  void _setTrim(EditableMedia m, Duration start, Duration end, Duration total) {
    final s = start <= Duration.zero ? null : start;
    final e = end >= total - const Duration(milliseconds: 1) ? null : end;
    setState(() => m.edit = m.edit.withTrim(s, e));
    _videos[m]?.setTrim(s, e);
  }

  void _applyTrim(EditableMedia m, MediaEdit next) {
    setState(() => m.edit = next);
    final c = _videos[m];
    if (c != null) {
      c.setTrim(next.trimStart, next.trimEnd);
      c.endScrub();
    }
  }

  void _undoTrim(EditableMedia m) => _applyTrim(m, m.history.undo(const TrimSetting(), m.edit));

  void _resetTrim(EditableMedia m) {
    final next = EditHistory.reset(const TrimSetting(), m.edit);
    m.history.record(const TrimSetting(), m.edit, next);
    _applyTrim(m, next);
  }

  void _resetAll() {
    for (final s in [const FilterSetting(), for (final a in Adjustment.values) AdjustSetting(a)]) {
      if (!EditHistory.settingEquals(s, _look, MediaEdit.none)) _resetLook(s);
    }
    if (!widget.batch && _current.isVideo && _current.edit.hasTrim) _resetTrim(_current);
  }

  void _showPage(int i) {
    for (final entry in _videos.entries) {
      if (entry.key != widget.items[i]) entry.value.pause();
    }
    setState(() {
      _index = i;
      _comparing = false;
    });
    final m = widget.items[i];
    if (m.isVideo) _videoFor(m).play();
  }

  void _jumpTo(int i) {
    if (_pages.hasClients) _pages.animateToPage(i, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final base = Theme.of(context);
    final dark = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: base.colorScheme.primary,
      textTheme: base.textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    );
    final tabs = [_Tab.filter, _Tab.adjust, if (_hasVideo) _Tab.trim];
    return Theme(
      data: dark,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(widget.batch ? l10n.mediaEditAllTitle(widget.items.length) : l10n.mediaEditTitle),
          actions: [
            IconButton(tooltip: l10n.mediaResetAll, icon: const Icon(Icons.restart_alt), onPressed: _resetAll),
            TextButton(onPressed: () => Navigator.of(context).maybePop(), child: Text(l10n.mediaDone)),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(children: [
            Expanded(child: _preview(context)),
            if (widget.batch)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  l10n.mediaBatchNote(widget.items.length),
                  textAlign: TextAlign.center,
                  style: dark.textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ),
            SizedBox(height: 184, child: _panel(context)),
            _tabBar(context, tabs),
          ]),
        ),
      ),
    );
  }

  // ── Preview ─────────────────────────────────────────────────────────────────

  Widget _preview(BuildContext context) {
    final l10n = context.l10n;
    Widget page(EditableMedia m) {
      final edit = _comparing && m == _current ? m.edit.withLookOf(MediaEdit.none) : m.edit;
      final view = m.isVideo
          ? GestureDetector(
              onTap: () => _videoFor(m).toggle(),
              child: Stack(fit: StackFit.expand, children: [
                EditedVideo(controller: _videoFor(m), edit: edit),
                ListenableBuilder(
                  listenable: _videoFor(m),
                  builder: (context, _) {
                    final c = _videoFor(m);
                    return c.ready && !c.isPlaying ? const Center(child: PlayBadge()) : const SizedBox.shrink();
                  },
                ),
              ]),
            )
          : EditedImage(media: m, edit: edit);
      return Semantics(
        hint: l10n.mediaHoldToCompare,
        child: GestureDetector(
          onLongPressStart: (_) => setState(() => _comparing = true),
          onLongPressEnd: (_) => setState(() => _comparing = false),
          onLongPressCancel: () => setState(() => _comparing = false),
          child: Padding(padding: const EdgeInsets.all(12), child: view),
        ),
      );
    }

    return Stack(children: [
      Positioned.fill(
        child: widget.batch
            ? PageView.builder(
                controller: _pages,
                itemCount: widget.items.length,
                onPageChanged: _showPage,
                itemBuilder: (context, i) => page(widget.items[i]),
              )
            : page(_current),
      ),
      if (widget.batch)
        Positioned(
          top: 16,
          right: 20,
          child: _chip(l10n.feedMediaIndex(_index + 1, widget.items.length)),
        ),
      if (_comparing) Positioned(top: 16, left: 20, child: _chip(l10n.mediaOriginal)),
    ]);
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  // ── Tabs ────────────────────────────────────────────────────────────────────

  Widget _tabBar(BuildContext context, List<_Tab> tabs) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    String label(_Tab t) => switch (t) {
      _Tab.filter => l10n.mediaTabFilter,
      _Tab.adjust => l10n.mediaTabAdjust,
      _Tab.trim => l10n.mediaTabTrim,
    };
    return Row(children: [
      for (final t in tabs)
        Expanded(
          child: InkWell(
            onTap: () => setState(() {
              _tab = t;
              _tool = null;
            }),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _tab == t ? cs.primary : Colors.white12, width: _tab == t ? 2 : 1)),
              ),
              child: Text(
                label(t),
                style: TextStyle(color: _tab == t ? Colors.white : Colors.white60, fontWeight: _tab == t ? FontWeight.w700 : FontWeight.w500),
              ),
            ),
          ),
        ),
    ]);
  }

  Widget _panel(BuildContext context) {
    if (!widget.batch && !_current.canEdit) {
      return Center(child: Text(context.l10n.mediaCantEdit, style: const TextStyle(color: Colors.white70)));
    }
    return switch (_tab) {
      _Tab.filter => _filterPanel(context),
      _Tab.adjust => _tool == null ? _toolList(context) : _adjustPanel(context, _tool!),
      _Tab.trim => _trimPanel(context),
    };
  }

  // ── Filter ──────────────────────────────────────────────────────────────────

  Widget _filterPanel(BuildContext context) {
    final l10n = context.l10n;
    final look = _look;
    const setting = FilterSetting();
    return Column(children: [
      _SettingBar(
        title: filterName(l10n, look.filter),
        value: look.hasFilter ? '${(look.filterStrength * 100).round()}' : null,
        onUndo: _lookHistory.canUndo(setting) ? () => _undoLook(setting) : null,
        onReset: look.filter == 'normal' ? null : () => _resetLook(setting),
      ),
      SizedBox(
        height: 36,
        child: look.hasFilter || look.filter != 'normal'
            ? Slider(
                value: look.filterStrength,
                label: l10n.mediaFilterStrength,
                semanticFormatterCallback: (v) => '${l10n.mediaFilterStrength} ${(v * 100).round()}',
                onChangeStart: (_) => _dragStart = _look,
                onChanged: (v) => _setLook(_look.withFilter(look.filter, v)),
                onChangeEnd: (_) {
                  if (_dragStart != null) _lookHistory.record(setting, _dragStart!, _look);
                  _dragStart = null;
                },
              )
            : null,
      ),
      Expanded(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: FilterPreset.all.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            final preset = FilterPreset.all[i];
            final selected = look.filter == preset.id;
            return Semantics(
              button: true,
              selected: selected,
              label: filterName(l10n, preset.id),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  if (selected) return;
                  _changeLook(setting, _look.withFilter(preset.id, 1));
                },
                child: Column(children: [
                  Text(
                    filterName(l10n, preset.id),
                    style: TextStyle(fontSize: 11, color: selected ? Colors.white : Colors.white60, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: selected ? Colors.white : Colors.transparent, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: _FilterThumb(media: _current, edit: MediaEdit(filter: preset.id)),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  // ── Adjust ──────────────────────────────────────────────────────────────────

  Widget _toolList(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
      itemCount: Adjustment.values.length,
      separatorBuilder: (_, _) => const SizedBox(width: 8),
      itemBuilder: (context, i) {
        final a = Adjustment.values[i];
        final changed = _look.value(a) != 0;
        return Semantics(
          button: true,
          label: adjustmentName(l10n, a),
          value: changed ? _signed(_look.value(a)) : null,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _tool = a),
            child: SizedBox(
              width: 76,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(adjustmentName(l10n, a), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 8),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white38)),
                  child: Icon(adjustmentIcon(a), color: Colors.white),
                ),
                const SizedBox(height: 6),
                // Instagram's "this one's been changed" dot.
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: changed ? cs.primary : Colors.transparent),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _adjustPanel(BuildContext context, Adjustment a) {
    final l10n = context.l10n;
    final setting = AdjustSetting(a);
    final v = _look.value(a);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      _SettingBar(
        leading: IconButton(
          tooltip: l10n.mediaBackToTools,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _tool = null),
        ),
        title: adjustmentName(l10n, a),
        value: _signed(v),
        onUndo: _lookHistory.canUndo(setting) ? () => _undoLook(setting) : null,
        onReset: v == 0 ? null : () => _resetLook(setting),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Slider(
          value: v,
          min: a.min,
          max: 1,
          semanticFormatterCallback: (x) => '${adjustmentName(l10n, a)} ${_signed(x)}',
          onChangeStart: (_) => _dragStart = _look,
          onChanged: (x) {
            // Snap to 0 near the middle, like Instagram's detent.
            final snapped = !a.isOneSided && x.abs() < 0.03 ? 0.0 : x;
            _setLook(_look.withAdjustment(a, double.parse(snapped.toStringAsFixed(2))));
          },
          onChangeEnd: (_) {
            if (_dragStart != null) _lookHistory.record(setting, _dragStart!, _look);
            _dragStart = null;
          },
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  static String _signed(double v) {
    final n = (v * 100).round();
    return n > 0 ? '+$n' : '$n';
  }

  // ── Trim ────────────────────────────────────────────────────────────────────

  Widget _trimPanel(BuildContext context) {
    final l10n = context.l10n;
    final videos = [for (var i = 0; i < widget.items.length; i++) if (widget.items[i].isVideo) i];
    final m = _current;
    return Column(children: [
      if (widget.batch && videos.length > 1 || !m.isVideo)
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: videos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 6),
            itemBuilder: (context, j) {
              final i = videos[j];
              final selected = i == _index;
              return ChoiceChip(
                label: Text(l10n.mediaVideoNumber(j + 1)),
                selected: selected,
                avatar: widget.items[i].edit.hasTrim ? const Icon(Icons.content_cut, size: 14) : null,
                onSelected: (_) => _jumpTo(i),
              );
            },
          ),
        ),
      if (!m.isVideo)
        Expanded(child: Center(child: Text(l10n.mediaTrimPickVideo, style: const TextStyle(color: Colors.white70))))
      else
        Expanded(
          child: ListenableBuilder(
            listenable: _videoFor(m),
            builder: (context, _) {
              final c = _videoFor(m);
              final total = c.ready ? c.duration : (m.duration ?? Duration.zero);
              if (total <= Duration.zero) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              final start = m.edit.trimStart ?? Duration.zero;
              final end = m.edit.trimEnd ?? total;
              const setting = TrimSetting();
              return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                _SettingBar(
                  title: l10n.mediaTrimSummary(
                    formatDuration(start.inMilliseconds),
                    formatDuration(end.inMilliseconds),
                    formatDuration((end - start).inMilliseconds),
                  ),
                  onUndo: m.history.canUndo(setting) ? () => _undoTrim(m) : null,
                  onReset: m.edit.hasTrim ? () => _resetTrim(m) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TrimTimeline(
                    file: m.original.file,
                    duration: total,
                    start: start,
                    end: end,
                    position: c.position,
                    onChangeStart: () => _dragStart = m.edit,
                    onChanged: (s, e) => _setTrim(m, s, e, total),
                    onScrub: c.scrubTo,
                    onChangeEnd: () {
                      if (_dragStart != null) m.history.record(setting, _dragStart!, m.edit);
                      _dragStart = null;
                      c.endScrub();
                    },
                  ),
                ),
              ]);
            },
          ),
        ),
    ]);
  }
}

/// "[←] Brightness +25      [undo] Reset" — the controls every setting has.
class _SettingBar extends StatelessWidget {
  const _SettingBar({required this.title, this.value, this.leading, required this.onUndo, required this.onReset});

  final String title;
  final String? value;
  final Widget? leading;
  final VoidCallback? onUndo;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(leading == null ? 16 : 4, 4, 8, 0),
      child: Row(children: [
        ?leading,
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: title, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (value != null) TextSpan(text: '   $value', style: const TextStyle(color: Colors.white70)),
            ]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(tooltip: l10n.mediaUndo, icon: const Icon(Icons.undo), onPressed: onUndo),
        TextButton(onPressed: onReset, child: Text(l10n.mediaReset)),
      ]),
    );
  }
}

/// A small preview of [media] with [edit]: the photo, or a video's first frame.
class _FilterThumb extends StatelessWidget {
  const _FilterThumb({required this.media, required this.edit});

  final EditableMedia media;
  final MediaEdit edit;

  @override
  Widget build(BuildContext context) {
    if (!media.isVideo) return EditedImage(media: media, edit: edit, fit: BoxFit.cover, cacheWidth: 200);
    final duration = media.duration ?? const Duration(seconds: 1);
    return FutureBuilder<List<Uint8List>>(
      future: VideoFrames.of(media.original.file, duration, 1, size: 160),
      builder: (context, snap) {
        final frame = snap.data?.firstOrNull;
        if (frame == null) return const ColoredBox(color: Colors.white12);
        final image = Image.memory(frame, fit: BoxFit.cover, gaplessPlayback: true);
        return edit.hasColorMatrix ? ColorFiltered(colorFilter: ColorFilter.matrix(edit.colorMatrix), child: image) : image;
      },
    );
  }
}

String filterName(AppLocalizations l10n, String id) => switch (id) {
  'vivid' => l10n.mediaFilterVivid,
  'punch' => l10n.mediaFilterPunch,
  'golden' => l10n.mediaFilterGolden,
  'arctic' => l10n.mediaFilterArctic,
  'rose' => l10n.mediaFilterRose,
  'vintage' => l10n.mediaFilterVintage,
  'matte' => l10n.mediaFilterMatte,
  'dramatic' => l10n.mediaFilterDramatic,
  'sepia' => l10n.mediaFilterSepia,
  'mono' => l10n.mediaFilterMono,
  'noir' => l10n.mediaFilterNoir,
  _ => l10n.mediaFilterNormal,
};

String adjustmentName(AppLocalizations l10n, Adjustment a) => switch (a) {
  Adjustment.brightness => l10n.mediaAdjustBrightness,
  Adjustment.contrast => l10n.mediaAdjustContrast,
  Adjustment.saturation => l10n.mediaAdjustSaturation,
  Adjustment.warmth => l10n.mediaAdjustWarmth,
  Adjustment.tint => l10n.mediaAdjustTint,
  Adjustment.fade => l10n.mediaAdjustFade,
  Adjustment.vignette => l10n.mediaAdjustVignette,
};

IconData adjustmentIcon(Adjustment a) => switch (a) {
  Adjustment.brightness => Icons.wb_sunny_outlined,
  Adjustment.contrast => Icons.contrast,
  Adjustment.saturation => Icons.water_drop_outlined,
  Adjustment.warmth => Icons.thermostat,
  Adjustment.tint => Icons.palette_outlined,
  Adjustment.fade => Icons.gradient,
  Adjustment.vignette => Icons.vignette_outlined,
};
