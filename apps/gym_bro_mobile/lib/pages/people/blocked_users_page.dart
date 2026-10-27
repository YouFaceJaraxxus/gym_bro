import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/person_tile.dart';
import 'people_common.dart';

/// People I've blocked, with Unblock.
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final _api = ApiService();
  List<PersonSummary>? _people;
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
      final people = await _api.getBlockedUsers(token);
      if (!mounted) return;
      setState(() => _people = people);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = peopleErrorText(e));
    }
  }

  Future<void> _unblock(PersonSummary person) async {
    final l10n = context.l10n;
    setState(() => _busy.add(person.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.unblock(token, person.id);
      if (!mounted) return;
      setState(() => _people = _people?.where((p) => p.id != person.id).toList());
      showPeopleSnack(context, l10n.peopleUnblockedSnack(person.username));
    } catch (e) {
      if (!mounted) return;
      showPeopleSnack(context, peopleErrorText(e));
    } finally {
      if (mounted) setState(() => _busy.remove(person.id));
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
      body = ListView(children: [PeopleErrorState(message: _error!, onRetry: _load)]);
    } else if (people.isEmpty) {
      body = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [PeopleMessageState(icon: Icons.block, message: l10n.peopleBlockedUsersEmpty)],
      );
    } else {
      body = ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: people.length,
        itemBuilder: (context, i) {
          final p = people[i];
          final busy = _busy.contains(p.id);
          return PersonTile(
            key: ValueKey(p.id),
            person: p,
            trailing: OutlinedButton(
              onPressed: busy ? null : () => _unblock(p),
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
                  : Text(l10n.peopleUnblock),
            ),
          );
        },
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(l10n.peopleBlockedUsers)),
      body: RefreshIndicator(onRefresh: _load, child: body),
    );
  }
}
