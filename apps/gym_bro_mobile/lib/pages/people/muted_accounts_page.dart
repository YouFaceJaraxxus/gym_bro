import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/person_tile.dart';
import 'people_common.dart';
import 'user_profile_page.dart';

/// People whose posts and/or stories I muted, with what's muted and Unmute.
class MutedAccountsPage extends StatefulWidget {
  const MutedAccountsPage({super.key});

  @override
  State<MutedAccountsPage> createState() => _MutedAccountsPageState();
}

class _MutedAccountsPageState extends State<MutedAccountsPage> {
  final _api = ApiService();
  List<MutedPerson>? _people;
  final Set<String> _busy = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final people = await _api.getMutes(token);
      if (!mounted) return;
      setState(() => _people = people);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = peopleErrorText(e));
    }
  }

  Future<void> _unmute(MutedPerson row) async {
    final l10n = context.l10n;
    setState(() => _busy.add(row.person.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.setMute(token, row.person.id, posts: false, stories: false);
      if (!mounted) return;
      setState(() => _people = _people?.where((p) => p.person.id != row.person.id).toList());
      showPeopleSnack(context, l10n.profileExtrasUnmutedSnack(row.person.username));
    } catch (e) {
      if (!mounted) return;
      showPeopleSnack(context, peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _busy.remove(row.person.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final people = _people;
    final Widget body;
    if (people == null && _error == null) {
      body = Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading));
    } else if (people == null) {
      body = ListView(
        children: [PeopleErrorState(message: _error!, onRetry: _load)],
      );
    } else if (people.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PeopleMessageState(
            icon: Icons.volume_off_outlined,
            message: l10n.profileExtrasMutedEmpty,
            body: l10n.profileExtrasMutedEmptyBody,
          ),
        ],
      );
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: people.length,
        itemBuilder: (context, i) {
          final row = people[i];
          final busy = _busy.contains(row.person.id);
          return PersonTile(
            key: ValueKey(row.person.id),
            person: row.person,
            subtitle: muteSummary(l10n, row.muted),
            onTap: () => Navigator.of(context)
                .push<void>(MaterialPageRoute(builder: (_) => UserProfilePage(userId: row.person.id)))
                .then((_) => _load()),
            trailing: OutlinedButton(
              onPressed: busy ? null : () => _unmute(row),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: busy
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.commonLoading),
                    )
                  : Text(l10n.profileExtrasUnmute),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileExtrasMutedAccounts)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}

/// "Posts and stories muted" / "Posts muted" / "Stories muted".
String muteSummary(AppLocalizations l10n, MuteSettings m) => m.posts && m.stories
    ? l10n.profileExtrasMutedBoth
    : m.posts
    ? l10n.profileExtrasMutedPosts
    : l10n.profileExtrasMutedStories;

/// Instagram's "Mute" sheet: two switches (posts, stories) applied as they're
/// flipped. Returns the final settings (null when nothing changed).
Future<MuteSettings?> showMuteSheet(
  BuildContext context, {
  required PersonSummary person,
  required MuteSettings current,
}) {
  return showAppBottomSheet<MuteSettings>(
    context: context,
    builder: (_) => _MuteSheet(person: person, initial: current),
  );
}

class _MuteSheet extends StatefulWidget {
  const _MuteSheet({required this.person, required this.initial});

  final PersonSummary person;
  final MuteSettings initial;

  @override
  State<_MuteSheet> createState() => _MuteSheetState();
}

class _MuteSheetState extends State<_MuteSheet> {
  late MuteSettings _value = widget.initial;
  bool _busy = false;

  Future<void> _set({bool? posts, bool? stories}) async {
    final next = MuteSettings(posts: posts ?? _value.posts, stories: stories ?? _value.stories);
    final before = _value;
    setState(() {
      _value = next;
      _busy = true;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final saved = await ApiService().setMute(token, widget.person.id, posts: next.posts, stories: next.stories);
      if (mounted) setState(() => _value = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _value = before);
      showPeopleSnack(context, peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.profileExtrasMuteTitle(widget.person.username),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l10n.profileExtrasMuteBody, style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _value.posts,
              onChanged: _busy ? null : (v) => _set(posts: v),
              title: Text(l10n.profileExtrasMutePosts),
            ),
            SwitchListTile(
              value: _value.stories,
              onChanged: _busy ? null : (v) => _set(stories: v),
              title: Text(l10n.profileExtrasMuteStories),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(_value),
                child: Text(l10n.profileExtrasDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
