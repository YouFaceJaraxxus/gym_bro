import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import 'schedule_widgets.dart';
import '../../widgets/app_bottom_sheet.dart';

/// Lets a coach add people to [c]: members of its gym and their own approved
/// followers. Resolves to true when anyone was added.
Future<bool> showAddPeopleSheet(BuildContext context, GymClass c) async {
  final added = await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _AddPeopleSheet(gymClass: c),
  );
  return added ?? false;
}

class _AddPeopleSheet extends StatefulWidget {
  const _AddPeopleSheet({required this.gymClass});

  final GymClass gymClass;

  @override
  State<_AddPeopleSheet> createState() => _AddPeopleSheetState();
}

class _AddPeopleSheetState extends State<_AddPeopleSheet> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  List<AddablePerson> _people = [];
  bool _loading = true;
  String? _error;

  /// Bookings made in this sheet, by user id (the API list may be stale).
  final Map<String, BookingStatus> _added = {};
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final query = _searchCtrl.text;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final people = await _api.getAddablePeople(token, widget.gymClass.id, query: query);
      if (!mounted || query != _searchCtrl.text) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  Future<void> _add(AddablePerson p) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(p.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      final b = await _api.bookClass(token, widget.gymClass.id, userId: p.id);
      if (!mounted) return;
      setState(() => _added[p.id] = b.status);
      final name = p.fullName.isEmpty ? '@${p.username}' : p.fullName;
      messenger.showSnackBar(SnackBar(
        content: Text(b.status == BookingStatus.waitlisted
            ? l10n.trainingClassAddedToWaitlist(name)
            : l10n.trainingClassAddedPerson(name)),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _added.isNotEmpty);
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(l10n.trainingClassAddPeople, style: ts.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(l10n.trainingClassAddPeopleHint,
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.trainingClassAddPeopleSearch,
                  ),
                ),
              ),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_loading && _people.isEmpty) {
      return Center(child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(onPressed: _load, child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.trainingClassAddPeopleEmpty,
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    return ListView.builder(
      itemCount: _people.length,
      itemBuilder: (_, i) {
        final p = _people[i];
        final status = _added[p.id] ?? p.bookingStatus;
        final busy = _busy.contains(p.id);
        return ListTile(
          leading: UserAvatar(url: p.avatarUrl, initials: p.initials),
          title: Text(p.fullName.isEmpty ? '@${p.username}' : p.fullName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            [
              '@${p.username}',
              if (p.isMember) l10n.trainingClassPersonMember,
              if (p.followsYou) l10n.trainingClassPersonFollower,
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: status != null
              ? Text(status.label(l10n), style: TextStyle(color: cs.onSurfaceVariant))
              : FilledButton.tonal(
                  onPressed: busy ? null : () => _add(p),
                  child: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(l10n.trainingClassAdd),
                ),
        );
      },
    );
  }
}
