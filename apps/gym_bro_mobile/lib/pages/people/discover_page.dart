import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import '../../widgets/social_widgets.dart';
import 'people_common.dart';
import 'requests_page.dart';

/// How many suggestions go in the "People you may know" carousel; the rest
/// are listed under "More suggestions".
const _kCarouselCount = 10;
const _kRadii = [5, 25, 50];

/// The People tab body (no app bar: it sits inside the home shell): search,
/// requests banner, suggestions carousel, nearby people, more suggestions.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Search
  String _query = '';
  List<PersonSummary>? _results;
  bool _searching = false;
  String? _searchError;
  int _searchGen = 0;

  // Discovery
  SocialBadges? _badges;
  List<Suggestion>? _suggestions;
  String? _suggestionsError;
  final Set<String> _dismissed = {};

  // Nearby
  List<NearbyPerson>? _nearby;
  bool _needsLocation = false;
  bool _nearbyLoading = false;
  String? _nearbyError;
  bool _locating = false;
  String? _locationError;
  int _radius = 25;

  /// Relationship changes made here, so rows keep them when rebuilt.
  final Map<String, Relationship> _rels = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([_loadBadges(), _loadSuggestions(), _loadNearby()]);

  Future<void> _loadBadges() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final badges = await _api.getSocialBadges(token);
      if (!mounted) return;
      setState(() => _badges = badges);
    } catch (_) {
      // The banner is optional.
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() => _suggestionsError = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final s = await _api.getSuggestions(token, pageSize: 30);
      if (!mounted) return;
      setState(() => _suggestions = s);
    } catch (e) {
      if (!mounted) return;
      setState(() => _suggestionsError = peopleErrorText(e));
    }
  }

  Future<void> _loadNearby() async {
    setState(() {
      _nearbyLoading = true;
      _nearbyError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getNearby(token, radiusKm: _radius);
      if (!mounted) return;
      setState(() {
        _nearby = rows;
        _needsLocation = false;
      });
    } on LocationRequiredException {
      if (!mounted) return;
      setState(() {
        _nearby = null;
        _needsLocation = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _nearbyError = peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _nearbyLoading = false);
    }
  }

  Future<void> _shareLocation() async {
    final l10n = context.l10n;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final error = await shareCoarseLocation(l10n);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _locationError = error;
    });
    if (error == null) await _loadNearby();
  }

  void _setRadius(int km) {
    if (km == _radius) return;
    setState(() => _radius = km);
    _loadNearby();
  }

  // ── Search ──────────────────────────────────────────────────────────────

  void _onQueryChanged(String value) {
    setState(() {}); // clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value.trim()));
  }

  Future<void> _search(String q) async {
    if (q == _query && _results != null) return;
    final gen = ++_searchGen;
    setState(() {
      _query = q;
      _searchError = null;
      _searching = q.isNotEmpty;
      if (q.isEmpty) _results = null;
    });
    if (q.isEmpty) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.searchPeople(token, q);
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _results = rows;
        _searching = false;
      });
    } catch (e) {
      if (!mounted || gen != _searchGen) return;
      setState(() {
        _searchError = peopleErrorText(e);
        _searching = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    _search('');
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _onRel(String id, Relationship rel) => setState(() => _rels[id] = rel);

  Widget _relButton(PersonSummary p) =>
      RelationshipButton(person: p, relationship: _rels[p.id], onChanged: (r) => _onRel(p.id, r));

  Future<void> _openRequests() async {
    final badges = _badges;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => RequestsPage(initialTab: (badges?.followRequests ?? 0) == 0 && (badges?.friendRequests ?? 0) > 0 ? 1 : 0),
    ));
    if (mounted) _loadBadges();
  }

  List<Suggestion> get _visibleSuggestions =>
      (_suggestions ?? const <Suggestion>[]).where((s) => !_dismissed.contains(s.person.id)).toList();

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onQueryChanged,
            onSubmitted: (v) {
              _debounce?.cancel();
              _search(v.trim());
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.peopleSearchHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(tooltip: l10n.commonClose, icon: const Icon(Icons.close), onPressed: _clearSearch),
            ),
          ),
        ),
        Expanded(child: _query.isNotEmpty ? _buildSearchResults() : _buildDiscover()),
      ],
    );
  }

  Widget _buildSearchResults() {
    final l10n = context.l10n;
    final results = _results;
    if (_searching && results == null) {
      return Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading));
    }
    if (_searchError != null) {
      return ListView(children: [PeopleErrorState(message: _searchError!, onRetry: () => _search(_query))]);
    }
    if (results == null || results.isEmpty) {
      return ListView(
        children: [PeopleMessageState(icon: Icons.person_search_outlined, message: l10n.peopleNoMatches(_query))],
      );
    }
    return Column(
      children: [
        if (_searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.builder(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: results.length,
            itemBuilder: (context, i) {
              final p = results[i];
              return PersonTile(key: ValueKey(p.id), person: p, trailing: _relButton(p));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiscover() {
    final l10n = context.l10n;
    final suggestions = _visibleSuggestions;
    final carousel = suggestions.take(_kCarouselCount).toList();
    final more = suggestions.skip(_kCarouselCount).toList();
    final badges = _badges;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (badges != null && badges.requests > 0)
            SliverToBoxAdapter(child: _RequestsBanner(badges: badges, onTap: _openRequests)),
          SliverToBoxAdapter(child: _SectionHeader(title: l10n.peopleSuggestionsTitle)),
          SliverToBoxAdapter(child: _buildCarousel(carousel)),
          SliverToBoxAdapter(
            child: _SectionHeader(
              title: l10n.peopleNearbyTitle,
              trailing: _needsLocation || _nearby == null
                  ? null
                  : Wrap(
                      spacing: 6,
                      children: [
                        for (final km in _kRadii)
                          ChoiceChip(
                            label: Text(l10n.peopleRadiusKm(km)),
                            selected: _radius == km,
                            visualDensity: VisualDensity.compact,
                            onSelected: (_) => _setRadius(km),
                          ),
                      ],
                    ),
            ),
          ),
          ..._buildNearby(),
          if (more.isNotEmpty) ...[
            SliverToBoxAdapter(child: _SectionHeader(title: l10n.peopleMoreSuggestions)),
            SliverList.builder(
              itemCount: more.length,
              itemBuilder: (context, i) {
                final s = more[i];
                return PersonTile(
                  key: ValueKey(s.person.id),
                  person: s.person,
                  subtitle: s.reasons.isEmpty
                      ? '@${s.person.username}'
                      : s.reasons.take(2).map((r) => suggestionReasonText(l10n, r)).join(' · '),
                  trailing: _relButton(s.person),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildCarousel(List<Suggestion> carousel) {
    final l10n = context.l10n;
    if (_suggestions == null && _suggestionsError == null) {
      return SizedBox(height: 120, child: Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading)));
    }
    if (_suggestionsError != null && _suggestions == null) {
      return PeopleErrorState(message: _suggestionsError!, onRetry: _loadSuggestions);
    }
    if (carousel.isEmpty) {
      return PeopleMessageState(icon: Icons.group_add_outlined, message: l10n.peopleNoSuggestions);
    }
    return SizedBox(
      height: 238,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: carousel.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final s = carousel[i];
          return _SuggestionCard(
            key: ValueKey(s.person.id),
            suggestion: s,
            button: _relButton(s.person),
            onDismiss: () => setState(() => _dismissed.add(s.person.id)),
          );
        },
      ),
    );
  }

  List<Widget> _buildNearby() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (_needsLocation) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.near_me_outlined, color: cs.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l10n.peopleNearbyPrivacyTitle, style: text.titleSmall)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.peopleNearbyPrivacyBody, style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    if (_locationError != null) ...[
                      const SizedBox(height: 8),
                      Text(_locationError!, style: text.bodySmall?.copyWith(color: cs.error)),
                    ],
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _locating ? null : _shareLocation,
                      icon: _locating
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.commonLoading),
                            )
                          : const Icon(Icons.my_location),
                      label: Text(l10n.peopleShareLocation),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ];
    }
    final nearby = _nearby;
    if (nearby == null) {
      if (_nearbyError != null) {
        return [SliverToBoxAdapter(child: PeopleErrorState(message: _nearbyError!, onRetry: _loadNearby))];
      }
      return [
        SliverToBoxAdapter(
          child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading))),
        ),
      ];
    }
    return [
      if (_nearbyLoading) const SliverToBoxAdapter(child: LinearProgressIndicator(minHeight: 2)),
      if (nearby.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(l10n.peopleNearbyEmpty(_radius), style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
        )
      else
        SliverList.builder(
          itemCount: nearby.length,
          itemBuilder: (context, i) {
            final n = nearby[i];
            return PersonTile(
              key: ValueKey('nearby-${n.person.id}'),
              person: n.person,
              subtitle: '${distanceLabel(l10n, n.distanceKm)} · @${n.person.username}',
              trailing: _relButton(n.person),
            );
          },
        ),
    ];
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({required this.badges, required this.onTap});

  final SocialBadges badges;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final parts = [
      if (badges.followRequests > 0) l10n.peopleFollowRequestsCount(badges.followRequests),
      if (badges.friendRequests > 0) l10n.peopleFriendRequestsCount(badges.friendRequests),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Material(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Badge.count(
                  count: badges.requests,
                  child: Icon(Icons.person_add_alt_1_outlined, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.peopleRequestsTitle,
                        style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                      ),
                      Text(parts.join(' · '), style: TextStyle(color: cs.onPrimaryContainer)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cs.onPrimaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({super.key, required this.suggestion, required this.button, required this.onDismiss});

  final Suggestion suggestion;
  final Widget button;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = suggestion.person;
    final reasons = suggestion.reasons;
    final primary = reasons.isEmpty ? null : reasons.first;
    final secondary = reasons.length > 1 ? reasons[1] : null;

    return SizedBox(
      width: 160,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openUserProfile(context, p.id),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                child: Column(
                  children: [
                    UserAvatar(url: p.avatarUrl, initials: p.initials, radius: 34),
                    const SizedBox(height: 8),
                    Text(
                      p.fullName.isEmpty ? p.username : p.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    if (primary != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(suggestionReasonIcon(primary), size: 14, color: cs.primary),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              suggestionReasonText(l10n, primary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      )
                    else
                      Text('@${p.username}', maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    if (secondary != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        suggestionReasonText(l10n, secondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                    const Spacer(),
                    SizedBox(width: double.infinity, child: button),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: l10n.peopleDismiss,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
