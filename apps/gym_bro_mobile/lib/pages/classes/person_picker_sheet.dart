import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import 'schedule_widgets.dart';

/// Picks one person a trainer may add as a customer or invite to a class:
/// their approved followers, members of gyms where they coach, and existing
/// customers (GET /customers/eligible). [excludeIds] are hidden. Resolves to
/// null when dismissed.
Future<EligibleCustomer?> showPersonPicker(
  BuildContext context, {
  required String title,
  String? hint,
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<EligibleCustomer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _PersonPicker(title: title, hint: hint, excludeIds: excludeIds),
  );
}

class _PersonPicker extends StatefulWidget {
  const _PersonPicker({required this.title, this.hint, required this.excludeIds});

  final String title;
  final String? hint;
  final Set<String> excludeIds;

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<EligibleCustomer> _people = [];
  bool _loading = true;
  String? _error;

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
      final people = await _api.getEligibleCustomers(token, query: query);
      if (!mounted || query != _searchCtrl.text) return;
      setState(() {
        _people = people.where((p) => !widget.excludeIds.contains(p.id)).toList();
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(widget.title, style: ts.titleLarge),
            ),
            if (widget.hint != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(widget.hint!, style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), _load);
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.trainerClassesPickerSearch,
                ),
              ),
            ),
            Expanded(child: _buildList()),
          ],
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
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    if (_people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.trainerClassesPickerEmpty,
              textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ),
      );
    }
    return ListView.builder(
      itemCount: _people.length,
      itemBuilder: (_, i) {
        final p = _people[i];
        final tags = [
          '@${p.username}',
          if (p.customerStatus == 'accepted') l10n.trainerClassesPickerCustomer,
          if (p.customerStatus == 'pending') l10n.trainerClassesPickerCustomerPending,
          if (p.isMember) l10n.trainerClassesPickerMember,
          if (p.followsYou) l10n.trainerClassesPickerFollower,
        ];
        return ListTile(
          leading: UserAvatar(url: p.avatarUrl, initials: p.initials),
          title: Text(p.fullName.isEmpty ? '@${p.username}' : p.fullName,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(tags.join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context, p),
        );
      },
    );
  }
}
