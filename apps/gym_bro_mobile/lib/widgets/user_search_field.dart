import 'dart:async';
import 'package:flutter/material.dart';
import '../models/user_search_result.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

const _kPageSize = 10;
const _kDebounce = Duration(milliseconds: 300);

class _CacheEntry {
  final List<UserSearchResult> results;
  final bool hasMore;
  final int pagesLoaded;

  const _CacheEntry({
    required this.results,
    required this.hasMore,
    required this.pagesLoaded,
  });

  _CacheEntry copyWith({
    List<UserSearchResult>? results,
    bool? hasMore,
    int? pagesLoaded,
  }) =>
      _CacheEntry(
        results: results ?? this.results,
        hasMore: hasMore ?? this.hasMore,
        pagesLoaded: pagesLoaded ?? this.pagesLoaded,
      );
}

/// Embedded paginated user search. Place inside a [SingleChildScrollView] —
/// it renders a [Column] and does not create its own scroll context.
///
/// Results are cached per query string for the widget's lifetime so that
/// switching between queries doesn't re-fetch already-seen pages.
class UserSearchField extends StatefulWidget {
  final void Function(UserSearchResult) onSelect;

  /// User IDs to hide from results (e.g. already-added members).
  final Set<String> excludeUserIds;

  /// ID of the user currently being added — shows a spinner on that tile.
  final String? addingUserId;

  /// Disables the search input and all Add buttons.
  final bool enabled;

  const UserSearchField({
    super.key,
    required this.onSelect,
    this.excludeUserIds = const {},
    this.addingUserId,
    this.enabled = true,
  });

  @override
  State<UserSearchField> createState() => _UserSearchFieldState();
}

class _UserSearchFieldState extends State<UserSearchField> {
  final _api = ApiService();
  final _ctrl = TextEditingController();
  Timer? _debounce;

  final Map<String, _CacheEntry> _cache = {};
  String _activeQuery = '';
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
    _search('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () => _search(_ctrl.text.trim()));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;

    if (_cache.containsKey(query)) {
      setState(() {
        _activeQuery = query;
        _loading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _activeQuery = query;
      _loading = true;
      _error = null;
    });

    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.searchUsers(token,
          query: query, page: 0, pageSize: _kPageSize);
      if (!mounted || _activeQuery != query) return;
      _cache[query] = _CacheEntry(
        results: results,
        hasMore: results.length >= _kPageSize,
        pagesLoaded: 1,
      );
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted || _activeQuery != query) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadMore() async {
    final cached = _cache[_activeQuery];
    if (cached == null || !cached.hasMore || _loadingMore) return;

    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final more = await _api.searchUsers(
        token,
        query: _activeQuery,
        page: cached.pagesLoaded,
        pageSize: _kPageSize,
      );
      if (!mounted) return;
      _cache[_activeQuery] = cached.copyWith(
        results: [...cached.results, ...more],
        hasMore: more.length >= _kPageSize,
        pagesLoaded: cached.pagesLoaded + 1,
      );
      setState(() => _loadingMore = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  List<UserSearchResult> get _visible {
    final cached = _cache[_activeQuery];
    if (cached == null) return [];
    return cached.results
        .where((u) => !widget.excludeUserIds.contains(u.id))
        .toList();
  }

  bool get _hasMore => _cache[_activeQuery]?.hasMore ?? false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final visible = _visible;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _ctrl,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: 'Search by name or username',
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _ctrl.clear();
                      _search('');
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
          )
        else if (visible.isEmpty && _ctrl.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No users found',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.outline),
            ),
          )
        else
          ...visible.map((u) => _UserTile(
                user: u,
                isAdding: widget.addingUserId == u.id,
                canAdd: widget.enabled && widget.addingUserId == null,
                onAdd: () => widget.onSelect(u),
              )),
        if (_hasMore && !_loading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _loadingMore
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : OutlinedButton(
                    onPressed: widget.enabled ? _loadMore : null,
                    child: const Text('Show more'),
                  ),
          ),
      ],
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserSearchResult user;
  final bool isAdding;
  final bool canAdd;
  final VoidCallback onAdd;

  const _UserTile({
    required this.user,
    required this.isAdding,
    required this.canAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final chips = _roleChips(user.roleEntries);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(child: Text(initials)),
        title: Text(user.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.username}  •  ${user.email}',
              style: const TextStyle(fontSize: 12),
            ),
            if (chips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: chips,
                ),
              ),
          ],
        ),
        isThreeLine: chips.isNotEmpty,
        trailing: isAdding
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton.tonal(
                onPressed: canAdd ? onAdd : null,
                child: const Text('Add'),
              ),
      ),
    );
  }

  static const _roleLabels = <String, String>{
    'member': 'Member',
    'employee': 'Employee',
    'employee_trainer': 'Emp. Trainer',
    'trainer': 'Trainer',
    'gym_owner': 'Gym Owner',
    'shop_owner': 'Shop Owner',
    'shop_vendor': 'Vendor',
  };

  List<Widget> _roleChips(List<UserRoleEntry> entries) {
    final seen = <String>{};
    final chips = <Widget>[];

    for (final e in entries) {
      if (!seen.add(e.type)) continue;
      chips.add(_chip(_roleLabels[e.type] ?? e.type));
      if (chips.length >= 3) break;
    }

    final remaining = entries.map((e) => e.type).toSet().length - chips.length;
    if (remaining > 0) chips.add(_chip('+$remaining'));

    return chips;
  }

  Widget _chip(String label) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      );
}
