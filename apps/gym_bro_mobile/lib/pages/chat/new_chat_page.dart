import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import 'chat_thread_page.dart';
import 'chat_widgets.dart';

/// Pick people to message: one → direct chat, several → a new group.
/// With [pickOnly] it just returns the selection (group "Add people").
class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key, this.pickOnly = false, this.excludeIds = const {}});

  final bool pickOnly;

  /// Shown as "Already in the group" and not selectable.
  final Set<String> excludeIds;

  /// Opens the picker and returns the chosen people (empty if cancelled).
  static Future<List<PersonSummary>> pickPeople(BuildContext context, {Set<String> exclude = const {}}) async {
    final picked = await Navigator.push<List<PersonSummary>>(
      context,
      MaterialPageRoute(builder: (_) => NewChatPage(pickOnly: true, excludeIds: exclude)),
    );
    return picked ?? const [];
  }

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _api = ApiService();
  final _search = TextEditingController();
  final _groupName = TextEditingController();
  Timer? _debounce;
  int _searchSeq = 0;

  final _selected = <String, PersonSummary>{};
  List<PersonSummary> _following = const [];
  List<PersonSummary> _suggested = const [];
  List<PersonSummary> _results = const [];
  String _query = '';
  bool _loading = true;
  bool _searching = false;
  bool _creating = false;
  String? _error;

  String get _me => chatMyId;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  Future<void> _loadDefaults() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final following = await _api.getPeopleList(token, _me, 'following', pageSize: 50);
      List<PersonSummary> suggested = const [];
      try {
        suggested = (await _api.getSuggestions(token, pageSize: 20)).map((s) => s.person).toList();
      } catch (_) {}
      if (!mounted) return;
      final followingIds = following.map((p) => p.id).toSet();
      setState(() {
        _following = following.where((p) => p.id != _me).toList();
        _suggested = suggested.where((p) => p.id != _me && !followingIds.contains(p.id)).toList();
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = chatErrorText(e);
      });
    }
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() {
      _query = q;
      _searching = true;
    });
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    final seq = ++_searchSeq;
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.searchPeople(token, q);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = results.where((p) => p.id != _me).toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = const [];
        _searching = false;
      });
      showChatSnack(context, chatErrorText(e));
    }
  }

  void _toggle(PersonSummary p) {
    setState(() {
      if (_selected.remove(p.id) == null) _selected[p.id] = p;
    });
  }

  Future<void> _done() async {
    if (_selected.isEmpty || _creating) return;
    final people = _selected.values.toList();
    if (widget.pickOnly) {
      Navigator.pop(context, people);
      return;
    }
    final nav = Navigator.of(context);
    setState(() => _creating = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final name = _groupName.text.trim();
      final conversation = people.length == 1
          ? await _api.openDirectChat(token, people.first.id)
          : await _api.createGroupChat(token, userIds: people.map((p) => p.id).toList(), title: name.isEmpty ? null : name);
      nav.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => ChatThreadPage(conversationId: conversation.id, initial: conversation),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      showChatSnack(context, chatErrorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final count = _selected.length;
    final buttonLabel = widget.pickOnly
        ? (count == 0 ? l10n.chatAddPeople : l10n.chatAddCount(count))
        : count >= 2
            ? l10n.chatCreateGroup
            : l10n.chatStartChat;
    return Scaffold(
      appBar: AppBar(title: Text(widget.pickOnly ? l10n.chatAddPeopleTitle : l10n.chatNewMessage)),
      body: Column(children: [
        if (_selected.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.chatTo, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                for (final p in _selected.values)
                  InputChip(
                    avatar: UserAvatar(url: p.avatarUrl, initials: p.initials, radius: 12),
                    label: Text(p.name.isEmpty ? p.username : p.name),
                    onDeleted: () => _toggle(p),
                    deleteButtonTooltipMessage: l10n.chatRemoveAttachment,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: _onQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.chatSearchPeople,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l10n.commonClose,
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _search.clear();
                        _onQuery('');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        if (!widget.pickOnly && count >= 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: TextField(
              controller: _groupName,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.chatGroupNameHint,
                prefixIcon: const Icon(Icons.groups_outlined),
                counterText: '',
                isDense: true,
              ),
            ),
          ),
        Expanded(child: _list()),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: count == 0 || _creating ? null : _done,
                child: _creating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(buttonLabel),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _list() {
    final l10n = context.l10n;
    if (_query.isNotEmpty) {
      if (_searching && _results.isEmpty) return const Center(child: CircularProgressIndicator());
      if (_results.isEmpty) return ChatEmptyState(icon: Icons.person_search_outlined, title: l10n.chatNoPeopleFound);
      return ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [for (final p in _results) _row(p)],
      );
    }
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ChatErrorState(
        message: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _loadDefaults();
        },
      );
    }
    if (_following.isEmpty && _suggested.isEmpty) {
      return ChatEmptyState(icon: Icons.person_search_outlined, title: l10n.chatSearchPeople);
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_following.isNotEmpty) ...[
          _section(l10n.chatFollowingSection),
          for (final p in _following) _row(p),
        ],
        if (_suggested.isNotEmpty) ...[
          _section(l10n.chatSuggestedSection),
          for (final p in _suggested) _row(p),
        ],
      ],
    );
  }

  Widget _section(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
    );
  }

  Widget _row(PersonSummary p) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final excluded = widget.excludeIds.contains(p.id);
    final selected = _selected.containsKey(p.id);
    return ListTile(
      enabled: !excluded,
      leading: UserAvatar(url: p.avatarUrl, initials: p.initials),
      title: Text(p.fullName.isEmpty ? p.username : p.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: excluded
          ? Text(l10n.chatAlreadyMember)
          : p.username.isEmpty
              ? null
              : Text('@${p.username}', maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: excluded
          ? null
          : Semantics(
              checked: selected,
              label: l10n.chatSelected,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? cs.primary : Colors.transparent,
                  border: Border.all(color: selected ? cs.primary : cs.outline, width: 2),
                ),
                child: selected ? Icon(Icons.check, size: 16, color: cs.onPrimary) : null,
              ),
            ),
      onTap: excluded ? null : () => _toggle(p),
    );
  }
}
