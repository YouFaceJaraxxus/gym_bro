import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import 'customer_detail_page.dart';
import 'person_picker_sheet.dart';
import 'schedule_widgets.dart';
import 'series_format.dart';
import '../../widgets/app_bottom_sheet.dart';

/// The trainer's customers and which of their classes each one takes or is
/// invited to. Adding someone invites them, optionally to some classes too.
class CustomersTab extends StatefulWidget {
  const CustomersTab({super.key});

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();
  List<Customer> _customers = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _customers.isEmpty;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final customers = await _api.getCustomers(token);
      if (!mounted) return;
      setState(() {
        _customers = customers;
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

  Future<void> _add() async {
    final added = await addCustomerFlow(
      context,
      exclude: {for (final c in _customers) c.userId},
    );
    if (added && mounted) _load();
  }

  Future<void> _open(Customer c) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => CustomerDetailPage(customer: c)),
    );
    if (mounted) _load();
  }

  List<Customer> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers
        .where(
          (c) =>
              c.fullName.toLowerCase().contains(q) ||
              c.username.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      floatingActionButton: _customers.isEmpty
          ? null
          : FloatingActionButton.extended(
              heroTag: 'customers-add',
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(l10n.customersAdd),
            ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    final l10n = context.l10n;
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(semanticsLabel: l10n.commonLoading),
      );
    }
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    if (_customers.isEmpty) {
      return ScheduleEmpty(
        icon: Icons.people_outline,
        title: l10n.customersEmptyTitle,
        message: l10n.customersEmptyMessage,
        action: FilledButton.tonalIcon(
          onPressed: _add,
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(l10n.customersAdd),
        ),
      );
    }
    final visible = _visible;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.customersSearch,
            ),
          ),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(l10n.customersNoMatches, textAlign: TextAlign.center),
          ),
        for (final c in visible)
          _CustomerRow(customer: c, onTap: () => _open(c)),
      ],
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({required this.customer, required this.onTap});

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar(url: c.avatarUrl, initials: c.initials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          c.fullName.isEmpty ? '@${c.username}' : c.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ts.titleSmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CustomerStatusChip(accepted: c.accepted),
                    ],
                  ),
                  Text(
                    '@${c.username}',
                    style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  if (c.classes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final k in c.classes)
                          CustomerClassChip(customerClass: k),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// "Customer" / "Invite pending".
class CustomerStatusChip extends StatelessWidget {
  const CustomerStatusChip({super.key, required this.accepted});

  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return _Pill(
      label: accepted
          ? l10n.customersStatusAccepted
          : l10n.customersStatusPending,
      background: accepted ? cs.primaryContainer : cs.surfaceContainerHighest,
      foreground: accepted ? cs.onPrimaryContainer : cs.onSurfaceVariant,
    );
  }
}

/// One of the trainer's classes a customer is in, invited to, or declined.
class CustomerClassChip extends StatelessWidget {
  const CustomerClassChip({super.key, required this.customerClass});

  final CustomerClass customerClass;

  @override
  Widget build(BuildContext context) {
    final k = customerClass;
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final state = enrollmentLabel(l10n, k.status);
    final (bg, fg, icon) = switch (k.status) {
      EnrollmentStatus.accepted => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
        Icons.check,
      ),
      EnrollmentStatus.pending => (
        cs.tertiaryContainer,
        cs.onTertiaryContainer,
        Icons.schedule,
      ),
      EnrollmentStatus.declined => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
        Icons.close,
      ),
    };
    final muted = !k.active;
    return Semantics(
      label:
          '${k.title}: $state${muted ? ', ${l10n.customersClassPaused}' : ''}',
      excludeSemantics: true,
      child: Opacity(
        opacity: muted ? 0.55 : 1,
        child: _Pill(
          icon: muted ? Icons.pause : icon,
          label: k.title,
          background: bg,
          foreground: fg,
        ),
      ),
    );
  }
}

String enrollmentLabel(AppLocalizations l10n, EnrollmentStatus s) =>
    switch (s) {
      EnrollmentStatus.accepted => l10n.customersClassIn,
      EnrollmentStatus.pending => l10n.customersClassInvited,
      EnrollmentStatus.declined => l10n.customersClassDeclined,
    };

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: foreground);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

/// Picks someone (not in [exclude]), then optionally some of the trainer's
/// active classes, and adds them as a customer. Returns true when added.
Future<bool> addCustomerFlow(
  BuildContext context, {
  Set<String> exclude = const {},
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final person = await showPersonPicker(
    context,
    title: l10n.customersAddPickerTitle,
    hint: l10n.customersAddPickerHint,
    excludeIds: exclude,
  );
  if (person == null || !context.mounted) return false;
  final name = person.fullName.isEmpty
      ? '@${person.username}'
      : person.fullName;

  final seriesIds = await showAppBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _ClassChooser(name: name),
  );
  if (seriesIds == null) return false;

  try {
    final token = await AuthManager.instance.getValidToken();
    await ApiService().addCustomer(token, person.id, seriesIds: seriesIds);
    messenger.showSnackBar(SnackBar(content: Text(l10n.customersAdded(name))));
    return true;
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    return false;
  }
}

/// The trainer's active classes as checkboxes. Pops the chosen ids ([] for
/// "Just add"), or null when dismissed.
class _ClassChooser extends StatefulWidget {
  const _ClassChooser({required this.name});

  final String name;

  @override
  State<_ClassChooser> createState() => _ClassChooserState();
}

class _ClassChooserState extends State<_ClassChooser> {
  List<ClassSeries>? _series;
  String? _error;
  final Set<String> _picked = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final all = await ApiService().getClassSeries(token);
      if (!mounted) return;
      setState(
        () => _series = all
            .where((s) => s.state == ClassSeriesState.active && s.canEdit)
            .toList(),
      );
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final series = _series;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              l10n.customersChooseClassesTitle(widget.name),
              style: ts.titleLarge,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.customersChooseClassesHint,
              style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _error != null
                ? ScheduleError(message: _error!, onRetry: _load)
                : series == null
                ? Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: l10n.commonLoading,
                    ),
                  )
                : series.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.customersNoActiveClasses,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView(
                    children: [
                      for (final s in series)
                        CheckboxListTile(
                          value: _picked.contains(s.id),
                          onChanged: (v) => setState(
                            () => v == true
                                ? _picked.add(s.id)
                                : _picked.remove(s.id),
                          ),
                          title: Text(s.title),
                          subtitle: Text(seriesScheduleSummary(context, s)),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, <String>[]),
                      child: Text(l10n.customersJustAdd),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _picked.isEmpty
                          ? null
                          : () => Navigator.pop(context, _picked.toList()),
                      child: Text(
                        l10n.customersInviteToClasses(
                          _picked.isEmpty ? 1 : _picked.length,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
