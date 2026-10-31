import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../models/story.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import 'people_common.dart';

/// My close friends list (only I see it): who sees my close-friends stories
/// (the green ring). The list on top with a star to take someone off, then
/// my followers — searchable — each with a star to add them.
class CloseFriendsPage extends StatefulWidget {
  const CloseFriendsPage({super.key});

  @override
  State<CloseFriendsPage> createState() => _CloseFriendsPageState();
}

class _CloseFriendsPageState extends State<CloseFriendsPage> {
  final _api = ApiService();
  final _search = TextEditingController();
  Timer? _debounce;

  List<PersonSummary>? _friends;
  List<PersonSummary>? _followers;
  String? _error;
  bool _searching = false;
  int _seq = 0;

  /// Requests in flight, by user id.
  final Set<String> _busy = {};

  String? get _myId => AuthManager.instance.profile?.id;

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
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final friends = await _api.getCloseFriends(token);
      if (!mounted) return;
      setState(() => _friends = friends);
      await _loadFollowers();
    } catch (e) {
      if (mounted) setState(() => _error = peopleErrorText(e));
    }
  }

  Future<void> _loadFollowers() async {
    final me = _myId;
    if (me == null) return;
    final seq = ++_seq;
    setState(() => _searching = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final people = await _api.getPeopleList(
        token,
        me,
        'followers',
        query: _search.text.trim(),
        pageSize: 50,
      );
      if (mounted && seq == _seq) setState(() => _followers = people);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _followers = const []);
    } finally {
      if (mounted && seq == _seq) setState(() => _searching = false);
    }
  }

  void _onQuery(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _loadFollowers);
  }

  bool _isFriend(String id) => _friends?.any((p) => p.id == id) ?? false;

  Future<void> _toggle(PersonSummary person) async {
    if (_busy.contains(person.id)) return;
    final add = !_isFriend(person.id);
    final before = _friends ?? const <PersonSummary>[];
    setState(() {
      _busy.add(person.id);
      _friends = add
          ? [person, ...before]
          : before.where((p) => p.id != person.id).toList();
    });
    try {
      await _api.setCloseFriend(
        await AuthManager.instance.getValidToken(),
        person.id,
        add,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _friends = before);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(peopleErrorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(person.id));
    }
  }

  Widget _star(PersonSummary person) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final on = _isFriend(person.id);
    return IconButton(
      key: ValueKey('close-friend-${person.id}'),
      tooltip: on ? l10n.closeFriendsPageRemove : l10n.closeFriendsPageAdd,
      isSelected: on,
      onPressed: _busy.contains(person.id) ? null : () => _toggle(person),
      icon: Icon(Icons.star_border_rounded, color: cs.onSurfaceVariant),
      selectedIcon: const Icon(Icons.star_rounded, color: kCloseFriendsGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final friends = _friends;
    final followers = _followers;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.closeFriendsPageTitle)),
      body: _error != null && friends == null
          ? Center(
              child: PeopleErrorState(message: _error!, onRetry: _load),
            )
          : friends == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: kCloseFriendsGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.closeFriendsPageInfo,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: Text(
                        l10n.closeFriendsPageListTitle(friends.length),
                        style: tt.titleSmall,
                      ),
                    ),
                  ),
                  if (friends.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text(
                          l10n.closeFriendsPageEmpty,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: friends.length,
                      itemBuilder: (context, i) => PersonTile(
                        person: friends[i],
                        trailing: _star(friends[i]),
                      ),
                    ),
                  const SliverToBoxAdapter(child: Divider(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.closeFriendsPageFollowers,
                            style: tt.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            key: const ValueKey('close-friends-search'),
                            controller: _search,
                            onChanged: _onQuery,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: l10n.closeFriendsPageSearchHint,
                              isDense: true,
                              border: const OutlineInputBorder(),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (followers == null)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (followers.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _search.text.trim().isEmpty
                              ? l10n.closeFriendsPageNoFollowers
                              : l10n.closeFriendsPageNoMatch,
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: followers.length,
                      itemBuilder: (context, i) => PersonTile(
                        person: followers[i],
                        trailing: _star(followers[i]),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
    );
  }
}
