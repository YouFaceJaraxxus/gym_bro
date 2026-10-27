import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import 'people_common.dart';

enum PeopleListTab {
  followers('followers'),
  following('following'),
  friends('friends'),

  /// Friends we have in common (only when viewing someone else).
  mutual('mutual-friends');

  const PeopleListTab(this.apiValue);
  final String apiValue;
}

const _kPageSize = 30;

/// Followers / Following / Friends (+ Mutual for other people) of [userId],
/// with an in-list search.
class PeopleListPage extends StatefulWidget {
  const PeopleListPage({super.key, required this.userId, this.initialTab = PeopleListTab.followers, this.title});

  final String userId;
  final PeopleListTab initialTab;

  /// App bar title, usually "@username".
  final String? title;

  @override
  State<PeopleListPage> createState() => _PeopleListPageState();
}

class _PeopleListPageState extends State<PeopleListPage> {
  late final bool _isMe = widget.userId == AuthManager.instance.profile?.id;

  List<PeopleListTab> get _tabs =>
      _isMe ? const [PeopleListTab.followers, PeopleListTab.following, PeopleListTab.friends] : PeopleListTab.values;

  String _label(PeopleListTab t) {
    final l10n = context.l10n;
    return switch (t) {
      PeopleListTab.followers => l10n.peopleFollowers,
      PeopleListTab.following => l10n.peopleFollowing,
      PeopleListTab.friends => l10n.peopleFriends,
      PeopleListTab.mutual => l10n.peopleMutual,
    };
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    final initial = tabs.indexOf(widget.initialTab).clamp(0, tabs.length - 1);
    return DefaultTabController(
      length: tabs.length,
      initialIndex: initial,
      child: Scaffold(
        appBar: AppBar(
          title: widget.title == null ? null : Text(widget.title!),
          bottom: TabBar(
            isScrollable: tabs.length > 3,
            tabAlignment: tabs.length > 3 ? TabAlignment.start : null,
            tabs: [for (final t in tabs) Tab(text: _label(t))],
          ),
        ),
        body: TabBarView(
          children: [for (final t in tabs) _PeopleListView(userId: widget.userId, tab: t, isMe: _isMe)],
        ),
      ),
    );
  }
}

class _PeopleListView extends StatefulWidget {
  const _PeopleListView({required this.userId, required this.tab, required this.isMe});

  final String userId;
  final PeopleListTab tab;
  final bool isMe;

  @override
  State<_PeopleListView> createState() => _PeopleListViewState();
}

class _PeopleListViewState extends State<_PeopleListView> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  Timer? _debounce;

  List<PersonSummary> _people = [];
  String _query = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _private = false;
  String? _error;

  /// Ignores responses for an older query.
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getPeopleList(token, widget.userId, widget.tab.apiValue, query: _query, pageSize: _kPageSize);
      if (!mounted || gen != _generation) return;
      setState(() {
        _people = rows;
        _page = 0;
        _hasMore = rows.length >= _kPageSize;
        _private = false;
        _loading = false;
      });
    } on PrivateAccountException {
      if (!mounted || gen != _generation) return;
      setState(() {
        _private = true;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = peopleErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _loading) return;
    final gen = _generation;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getPeopleList(
        token,
        widget.userId,
        widget.tab.apiValue,
        query: _query,
        page: _page + 1,
        pageSize: _kPageSize,
      );
      if (!mounted || gen != _generation) return;
      final seen = _people.map((p) => p.id).toSet();
      setState(() {
        _people = [..._people, ...rows.where((p) => !seen.contains(p.id))];
        _page++;
        _hasMore = rows.length >= _kPageSize;
      });
    } catch (_) {
      // Keep what we have; the next scroll retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onQueryChanged(String value) {
    setState(() {}); // clear button visibility
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final q = value.trim();
      if (q == _query) return;
      _query = q;
      _load();
    });
  }

  void _updatePerson(String id, Relationship rel) {
    setState(() {
      _people = [for (final p in _people) p.id == id ? p.copyWith(relationship: rel) : p];
    });
  }

  Future<void> _removeFollower(PersonSummary person) async {
    final l10n = context.l10n;
    final ok = await confirmPeopleAction(
      context,
      title: l10n.peopleRemoveFollowerTitle(person.username),
      body: l10n.peopleRemoveFollowerBody,
      confirmLabel: l10n.peopleRemove,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final index = _people.indexWhere((p) => p.id == person.id);
    if (index < 0) return;
    setState(() => _people = [..._people]..removeAt(index));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeFollower(token, person.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _people = [..._people]..insert(index.clamp(0, _people.length), person));
      showPeopleSnack(context, peopleErrorText(e));
    }
  }

  String get _emptyText {
    final l10n = context.l10n;
    if (_query.isNotEmpty) return l10n.peopleNoMatches(_query);
    return switch (widget.tab) {
      PeopleListTab.followers => l10n.peopleListEmptyFollowers,
      PeopleListTab.following => l10n.peopleListEmptyFollowing,
      PeopleListTab.friends => l10n.peopleListEmptyFriends,
      PeopleListTab.mutual => l10n.peopleListEmptyMutual,
    };
  }

  Widget _trailing(PersonSummary person) {
    final button = RelationshipButton(person: person, onChanged: (rel) => _updatePerson(person.id, rel));
    if (!(widget.isMe && widget.tab == PeopleListTab.followers)) return button;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        IconButton(
          tooltip: context.l10n.peopleRemoveFollower,
          icon: const Icon(Icons.close),
          visualDensity: VisualDensity.compact,
          onPressed: () => _removeFollower(person),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;

    final Widget body;
    if (_loading && _people.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading)),
        ],
      );
    } else if (_private) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PeopleMessageState(icon: Icons.lock_outline, message: l10n.peoplePrivateTitle, body: l10n.peoplePrivateBody),
        ],
      );
    } else if (_error != null && _people.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [PeopleErrorState(message: _error!, onRetry: _load)],
      );
    } else if (_people.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [PeopleMessageState(icon: Icons.people_outline, message: _emptyText)],
      );
    } else {
      body = NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels > n.metrics.maxScrollExtent - 400) _loadMore();
          return false;
        },
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _people.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i >= _people.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final p = _people[i];
            return PersonTile(key: ValueKey(p.id), person: p, trailing: _trailing(p));
          },
        ),
      );
    }

    return Column(
      children: [
        if (!_private)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _search,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: l10n.peopleSearchInList,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.commonClose,
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _onQueryChanged('');
                        },
                      ),
              ),
            ),
          ),
        if (_loading && _people.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: RefreshIndicator(onRefresh: _load, child: body)),
      ],
    );
  }
}
