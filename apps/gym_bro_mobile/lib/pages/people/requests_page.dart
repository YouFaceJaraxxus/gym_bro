import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../models/social.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import 'people_common.dart';

enum _Kind { follow, friend, sent }

class _Row {
  final PersonSummary person;
  final int mutualCount;
  final DateTime? createdAt;

  /// Accepted in this session (row stays, showing the next step).
  final bool accepted;

  const _Row(this.person, {this.mutualCount = 0, this.createdAt, this.accepted = false});

  _Row accept(Relationship? rel) =>
      _Row(rel == null ? person : person.copyWith(relationship: rel), mutualCount: mutualCount, createdAt: createdAt, accepted: true);
}

/// Incoming follow requests, incoming friend requests and my sent friend requests.
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, this.initialTab = 0});

  /// 0 follow requests, 1 friend requests, 2 sent.
  final int initialTab;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  SocialBadges? _badges;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final badges = await ApiService().getSocialBadges(token);
      if (!mounted) return;
      setState(() => _badges = badges);
    } catch (_) {
      // Tab counts are optional.
    }
  }

  Tab _tab(String label, int count) => Tab(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[const SizedBox(width: 6), Badge.count(count: count)],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 3,
      initialIndex: widget.initialTab.clamp(0, 2),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.peopleRequestsTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              _tab(l10n.peopleFollowRequestsTab, _badges?.followRequests ?? 0),
              _tab(l10n.peopleFriendRequestsTab, _badges?.friendRequests ?? 0),
              Tab(text: l10n.peopleSentTab),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RequestsTab(kind: _Kind.follow, onChanged: _loadBadges),
            _RequestsTab(kind: _Kind.friend, onChanged: _loadBadges),
            _RequestsTab(kind: _Kind.sent, onChanged: _loadBadges),
          ],
        ),
      ),
    );
  }
}

class _RequestsTab extends StatefulWidget {
  const _RequestsTab({required this.kind, required this.onChanged});

  final _Kind kind;
  final VoidCallback onChanged;

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  List<_Row>? _rows;
  String? _error;
  final Set<String> _busy = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final List<_Row> rows = switch (widget.kind) {
        _Kind.follow => (await _api.getFollowRequests(token)).map((p) => _Row(p)).toList(),
        _Kind.friend => (await _api.getFriendRequests(token))
            .map((r) => _Row(r.person, mutualCount: r.mutualCount, createdAt: r.createdAt))
            .toList(),
        _Kind.sent => (await _api.getFriendRequests(token, outgoing: true))
            .map((r) => _Row(r.person, mutualCount: r.mutualCount, createdAt: r.createdAt))
            .toList(),
      };
      if (!mounted) return;
      setState(() => _rows = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = peopleErrorText(e));
    }
  }

  Future<void> _act(_Row row, {required bool positive}) async {
    final id = row.person.id;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final token = await AuthManager.instance.getValidToken();
      Relationship? rel;
      switch (widget.kind) {
        case _Kind.follow:
          await _api.respondToFollowRequest(token, id, accept: positive);
          // They now follow me: offer "Follow back".
          rel = (row.person.relationship ?? const Relationship()).copyWith(followedBy: FollowState.accepted);
        case _Kind.friend:
          rel = positive ? await _api.addFriend(token, id) : await _api.removeFriend(token, id);
        case _Kind.sent:
          await _api.removeFriend(token, id);
      }
      if (!mounted) return;
      setState(() {
        _rows = [
          for (final r in _rows ?? <_Row>[])
            if (r.person.id != id)
              r
            else if (positive && widget.kind != _Kind.sent)
              r.accept(rel),
        ];
      });
      widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      showPeopleSnack(context, peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Widget _trailing(_Row row) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final busy = _busy.contains(row.person.id);
    final compact = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 34)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
      visualDensity: VisualDensity.compact,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    if (busy) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.commonLoading),
      );
    }
    if (row.accepted) {
      if (widget.kind == _Kind.follow) {
        return RelationshipButton(person: row.person);
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.how_to_reg, size: 18, color: cs.primary),
          const SizedBox(width: 4),
          Text(l10n.peopleFriends, style: TextStyle(color: cs.primary)),
        ],
      );
    }
    final (String yes, String? no) = switch (widget.kind) {
      _Kind.follow => (l10n.commonConfirm, l10n.commonDelete),
      _Kind.friend => (l10n.peopleAccept, l10n.peopleDecline),
      _Kind.sent => (l10n.commonCancel, null),
    };
    if (widget.kind == _Kind.sent) {
      return OutlinedButton(onPressed: () => _act(row, positive: false), style: compact, child: Text(yes));
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton(onPressed: () => _act(row, positive: true), style: compact, child: Text(yes)),
        const SizedBox(width: 6),
        OutlinedButton(onPressed: () => _act(row, positive: false), style: compact, child: Text(no!)),
      ],
    );
  }

  String? _subtitle(_Row row) {
    final l10n = context.l10n;
    final parts = <String>[
      '@${row.person.username}',
      if (row.mutualCount > 0) l10n.peopleReasonMutual(row.mutualCount),
      if (row.createdAt != null && row.mutualCount == 0) relativeTime(l10n, row.createdAt!),
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final rows = _rows;
    final Widget body;
    if (rows == null && _error == null) {
      body = Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading));
    } else if (rows == null) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [PeopleErrorState(message: _error!, onRetry: _load)],
      );
    } else if (rows.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          switch (widget.kind) {
            _Kind.follow => PeopleMessageState(
              icon: Icons.person_add_alt_outlined,
              message: l10n.peopleNoFollowRequests,
              body: l10n.peopleNoFollowRequestsHint,
            ),
            _Kind.friend => PeopleMessageState(icon: Icons.people_outline, message: l10n.peopleNoFriendRequests),
            _Kind.sent => PeopleMessageState(icon: Icons.outbox_outlined, message: l10n.peopleNoSentRequests),
          },
        ],
      );
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length,
        itemBuilder: (context, i) {
          final row = rows[i];
          return PersonTile(
            key: ValueKey(row.person.id),
            person: row.person,
            subtitle: _subtitle(row),
            trailing: _trailing(row),
          );
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _load();
        widget.onChanged();
      },
      child: body,
    );
  }
}
