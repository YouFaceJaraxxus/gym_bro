import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../models/shared_content.dart';
import '../../models/story.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/post_grid.dart';
import '../../widgets/social_widgets.dart';
import '../feed/post_detail_page.dart';
import '../stories/story_viewer_page.dart';
import 'archive_calendar.dart';

/// My archive, Instagram-style and visible only to me: every story I posted
/// (live and expired) and the posts I archived, each on a month calendar.
/// A day with something shows its first item as a thumbnail; tapping it
/// narrows the list below to that day. The list toggle drops the calendar
/// and shows the whole month, newest first.
class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  bool _calendar = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.archiveTitle),
          actions: [
            IconButton(
              tooltip: _calendar ? l10n.archiveViewList : l10n.archiveViewCalendar,
              icon: Icon(_calendar ? Icons.view_agenda_outlined : Icons.calendar_month_outlined),
              onPressed: () => setState(() => _calendar = !_calendar),
            ),
          ],
          bottom: TabBar(tabs: [Tab(text: l10n.archiveTabStories), Tab(text: l10n.archiveTabPosts)]),
        ),
        body: TabBarView(children: [
          _MonthArchive<Story>(
            key: const PageStorageKey('archive-stories'),
            calendar: _calendar,
            hint: l10n.archiveStoriesHint,
            load: (from, to) async =>
                ApiService().getStoryArchive(await AuthManager.instance.getValidToken(), from: from, to: to),
            dateOf: (s) => s.createdAt,
            emptyText: l10n.archiveNoStories,
            thumbnail: (s) => _StoryThumb(story: s),
            items: (state, stories) => _storyGrid(state, stories),
          ),
          _MonthArchive<Post>(
            key: const PageStorageKey('archive-posts'),
            calendar: _calendar,
            hint: l10n.archivePostsHint,
            load: (from, to) async =>
                ApiService().getArchivedPosts(await AuthManager.instance.getValidToken(), from: from, to: to),
            dateOf: (p) => p.createdAt.toLocal(),
            emptyText: l10n.archiveNoPosts,
            thumbnail: (p) => IgnorePointer(child: PostGridTile(post: p, onTap: () {})),
            items: (state, posts) => SliverPostGrid(posts: posts, onTap: (p) => _openPost(state, p)),
          ),
        ]),
      ),
    );
  }

  /// Stories as 9:16 tiles; the viewer gets them in the order they were posted.
  Widget _storyGrid(_MonthArchiveState<Story> state, List<Story> stories) => SliverGrid.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 9 / 16,
    ),
    itemCount: stories.length,
    itemBuilder: (context, i) => _StoryTile(
      story: stories[i],
      onTap: () async {
        final ordered = [...stories]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        await openStoryList(context, ordered, initialIndex: ordered.indexOf(stories[i]));
        // Stories may have been deleted from the viewer.
        if (mounted) await state.reload();
      },
    ),
  );

  void _openPost(_MonthArchiveState<Post> state, Post post) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => PostDetailPage(
        postId: post.id,
        initial: post,
        // Shown on the profile again (or deleted): it leaves the archive.
        onChanged: (p) => p.isArchived ? state.replace(post, p) : state.remove(post),
        onDeleted: () => state.remove(post),
      ),
    ));
  }
}

/// One tab: a month of [T] on a calendar (or as a list), loaded a month at a
/// time and cached until pulled to refresh.
class _MonthArchive<T> extends StatefulWidget {
  const _MonthArchive({
    super.key,
    required this.calendar,
    required this.hint,
    required this.load,
    required this.dateOf,
    required this.emptyText,
    required this.thumbnail,
    required this.items,
  });

  final bool calendar;
  final String hint;

  /// Items created in [from, to), newest first.
  final Future<List<T>> Function(DateTime from, DateTime to) load;
  final DateTime Function(T item) dateOf;
  final String Function(String month) emptyText;
  final Widget Function(T item) thumbnail;

  /// The items under the calendar, as a sliver.
  final Widget Function(_MonthArchiveState<T> state, List<T> items) items;

  @override
  State<_MonthArchive<T>> createState() => _MonthArchiveState<T>();
}

class _MonthArchiveState<T> extends State<_MonthArchive<T>> with AutomaticKeepAliveClientMixin {
  DateTime _month = monthOf(DateTime.now());
  DateTime? _day;
  final Map<DateTime, List<T>> _cache = {};
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _ensure(_month);
  }

  Future<void> _ensure(DateTime month, {bool force = false}) async {
    if (!force && _cache.containsKey(month)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await widget.load(month, addMonths(month, 1));
      if (!mounted) return;
      setState(() => _cache[month] = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> reload() => _ensure(_month, force: true);

  // By the item's own month: the user may have moved on meanwhile.
  void remove(T item) {
    if (!mounted) return;
    setState(() => _cache[monthOf(widget.dateOf(item))]?.remove(item));
  }

  void replace(T old, T updated) {
    final list = _cache[monthOf(widget.dateOf(old))];
    final i = list?.indexOf(old) ?? -1;
    if (!mounted || i < 0) return;
    setState(() => list![i] = updated);
  }

  void _goTo(int delta) {
    setState(() {
      _month = addMonths(_month, delta);
      _day = null;
    });
    _ensure(_month);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final monthLabel = DateFormat.yMMMM(locale).format(_month);
    final items = _cache[_month];
    final byDay = items == null ? <DateTime, List<T>>{} : groupByDay(items, widget.dateOf);
    final day = widget.calendar ? _day : null;
    final shown = items == null ? null : (day == null ? items : byDay[day] ?? <T>[]);

    return RefreshIndicator(
      onRefresh: reload,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Icon(Icons.lock_outline, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.archiveOnlyYou} ${widget.hint}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
              ]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: Row(children: [
                IconButton(
                  tooltip: l10n.archivePrevMonth,
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _goTo(-1),
                ),
                Expanded(
                  child: Text(monthLabel, textAlign: TextAlign.center, style: tt.titleMedium),
                ),
                IconButton(
                  tooltip: l10n.archiveNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  onPressed: canGoToNextMonth(_month, DateTime.now()) ? () => _goTo(1) : null,
                ),
              ]),
            ),
          ),
          if (_loading && items == null) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
          if (widget.calendar)
            SliverToBoxAdapter(child: _buildCalendar(context, byDay, locale)),
          if (_error != null && items == null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l10n.archiveLoadFailed, style: tt.titleSmall),
                  const SizedBox(height: 4),
                  Text(_error!, style: tt.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: reload, icon: const Icon(Icons.refresh), label: Text(l10n.commonRetry)),
                ]),
              ),
            )
          else if (shown != null) ...[
            if (items!.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    day == null ? l10n.archiveWholeMonth(monthLabel) : DateFormat.MMMMEEEEd(locale).format(day),
                    style: tt.titleSmall,
                  ),
                ),
              ),
            if (shown.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      items.isEmpty
                          ? widget.emptyText(monthLabel)
                          : l10n.archiveNothingOnDay(DateFormat.MMMMd(locale).format(day!)),
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            else
              widget.items(this, shown),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar(BuildContext context, Map<DateTime, List<T>> byDay, String locale) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex == 0 ? DateTime.sunday : DateTime.monday;
    final weeks = monthGrid(_month, firstWeekday: firstWeekday);
    final names = DateFormat.E(locale);
    final today = dayOf(DateTime.now());
    // Any week (2026-10-05 is a Monday) for the weekday names.
    final headerStart = DateTime(2026, 10, 5 + (firstWeekday == DateTime.sunday ? -1 : 0));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Row(children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: ExcludeSemantics(
                child: Text(
                  names.format(headerStart.add(Duration(days: i))),
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        for (final week in weeks)
          Row(children: [
            for (final d in week)
              Expanded(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: d == null
                      ? const SizedBox.shrink()
                      : _DayCell<T>(
                          day: d,
                          items: byDay[d] ?? <T>[],
                          thumbnail: widget.thumbnail,
                          selected: _day == d,
                          today: d == today,
                          label: l10n.archiveDayLabel(DateFormat.MMMMEEEEd(locale).format(d), byDay[d]?.length ?? 0),
                          onTap: (byDay[d] ?? <T>[]).isEmpty
                              ? null
                              : () => setState(() => _day = _day == d ? null : d),
                        ),
                ),
              ),
          ]),
      ]),
    );
  }
}

/// A calendar day: its first item as a thumbnail with the day number (and a
/// count when there are several), or just the number when empty.
class _DayCell<T> extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.items,
    required this.thumbnail,
    required this.selected,
    required this.today,
    required this.label,
    this.onTap,
  });

  final DateTime day;
  final List<T> items;
  final Widget Function(T item) thumbnail;
  final bool selected;
  final bool today;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final number = Text(
      '${day.day}',
      style: tt.labelMedium?.copyWith(
        fontWeight: today ? FontWeight.w800 : FontWeight.w500,
        color: items.isEmpty ? (today ? cs.primary : cs.onSurfaceVariant) : Colors.white,
        shadows: items.isEmpty ? null : const [Shadow(color: Colors.black87, blurRadius: 4)],
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(fit: StackFit.expand, children: [
              if (items.isNotEmpty) thumbnail(items.first),
              if (items.isEmpty) Center(child: number) else Positioned(left: 4, top: 2, child: number),
              if (items.length > 1)
                Positioned(
                  right: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: Text('${items.length}', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              if (selected || (today && items.isNotEmpty))
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: selected ? cs.primary : cs.outline, width: selected ? 2.5 : 1),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// What a story looks like small: its photo, a dark tile for a video (no
/// frame decoding), or its colour with the text / shared thing's icon.
class _StoryThumb extends StatelessWidget {
  const _StoryThumb({required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final s = story;
    if (s.hasMedia && !s.isVideo) return MediaImage(url: s.mediaUrl!);
    if (s.isVideo) {
      return Container(
        color: const Color(0xFF1C1C1E),
        alignment: Alignment.center,
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
      );
    }
    return Container(
      color: s.backgroundColor,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: s.share != null
          ? Icon(shareKindIcon(s.share!.kind), color: Colors.white, size: 18)
          : Text(
              s.caption ?? '',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
            ),
    );
  }
}

/// A story in the grid: the thumbnail plus its time, caption and a "Live"
/// badge while it's still up.
class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story, required this.onTap});

  final Story story;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final s = story;
    final locale = Localizations.localeOf(context).toString();
    final time = DateFormat.MMMd(locale).add_jm().format(s.createdAt);
    final what = s.caption ??
        (s.share != null ? (s.share!.title ?? l10n.archiveStoryShared) : (s.hasMedia ? '' : l10n.archiveStoryText));
    return Semantics(
      button: true,
      label: [time, if (what.isNotEmpty) what, if (s.isLive) l10n.archiveStoryLive].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(fit: StackFit.expand, children: [
          _StoryThumb(story: s),
          if (s.hasMedia && s.caption != null)
            Positioned(
              left: 6,
              right: 6,
              bottom: 26,
              child: Text(
                s.caption!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]),
              ),
            ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 32,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54]),
              ),
            ),
          ),
          Positioned(
            left: 6,
            bottom: 5,
            child: Text(time, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
          if (s.isLive)
            Positioned(
              top: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                child: Text(l10n.archiveStoryLive, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ),
          if (s.viewCount != null && s.viewCount! > 0)
            Positioned(
              top: 6,
              right: 6,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.visibility_outlined, size: 12, color: Colors.white, shadows: [Shadow(color: Colors.black87, blurRadius: 4)]),
                const SizedBox(width: 2),
                Text('${s.viewCount}', style: const TextStyle(color: Colors.white, fontSize: 10, shadows: [Shadow(color: Colors.black87, blurRadius: 4)])),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// An icon for what a story / message shares.
IconData shareKindIcon(ShareKind kind) => switch (kind) {
  ShareKind.post => Icons.grid_on_rounded,
  ShareKind.story => Icons.amp_stories_outlined,
  ShareKind.user => Icons.person_outline,
  ShareKind.business => Icons.storefront_outlined,
  ShareKind.shopItem => Icons.shopping_bag_outlined,
  ShareKind.workout || ShareKind.training || ShareKind.exercise || ShareKind.routine => Icons.fitness_center,
  ShareKind.meal || ShareKind.recipe || ShareKind.foodItem || ShareKind.dailyMealPlan || ShareKind.mealPlan =>
    Icons.restaurant_outlined,
};
