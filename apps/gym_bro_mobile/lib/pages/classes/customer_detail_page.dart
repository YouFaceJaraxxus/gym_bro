import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/class_series.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/social_widgets.dart';
import '../member_progress_page.dart';
import '../people/user_profile_page.dart';
import 'customers_tab.dart';
import 'schedule_widgets.dart';
import 'series_format.dart';

/// One customer: who they are, their progress (once they accepted), and each
/// of the trainer's classes with this person's invite state and what the
/// trainer can do about it. Pops true when the customer was removed.
class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({super.key, required this.customer});

  /// Shown straight away; refreshed from GET /customers.
  final Customer customer;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  final _api = ApiService();
  late Customer _customer = widget.customer;
  List<ClassSeries>? _series;
  String? _error;
  bool _gone = false;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getCustomers(token),
        _api.getClassSeries(token),
      ]);
      if (!mounted) return;
      final customers = results[0] as List<Customer>;
      final match = customers
          .where((c) => c.userId == _customer.userId)
          .firstOrNull;
      setState(() {
        if (match != null) _customer = match;
        _gone = match == null;
        _series = (results[1] as List<ClassSeries>)
            .where((s) => s.canEdit)
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    }
  }

  String get _name => _customer.fullName.isEmpty
      ? '@${_customer.username}'
      : _customer.fullName;

  EnrollmentStatus? _statusIn(ClassSeries s) =>
      _customer.classes.where((k) => k.seriesId == s.id).firstOrNull?.status;

  Future<void> _act(
    ClassSeries s,
    Future<void> Function(String token) call,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy.add(s.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await call(token);
      messenger.showSnackBar(SnackBar(content: Text(done)));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  Future<void> _invite(ClassSeries s) => _act(
    s,
    (t) => _api.inviteToClassSeries(t, s.id, _customer.userId),
    context.l10n.customersInvited,
  );

  Future<void> _cancelInvite(ClassSeries s) => _act(
    s,
    (t) => _api.removeClassSeriesEnrollment(t, s.id, _customer.userId),
    context.l10n.customersInviteCancelled,
  );

  Future<void> _removeFromClass(ClassSeries s) async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.customersRemoveFromClassTitle(s.title),
      message: l10n.customersRemoveFromClassMessage,
      confirmLabel: l10n.customersRemove,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _act(
      s,
      (t) => _api.removeClassSeriesEnrollment(t, s.id, _customer.userId),
      l10n.customersRemovedFromClass,
    );
  }

  Future<void> _removeCustomer() async {
    final l10n = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l10n.customersRemoveCustomerTitle(_name),
      message: l10n.customersRemoveCustomerMessage,
      confirmLabel: l10n.customersRemove,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.removeCustomer(token, _customer.userId);
      messenger.showSnackBar(SnackBar(content: Text(l10n.customersRemoved)));
      nav.pop(true);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(e))));
    }
  }

  void _openProfile() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => UserProfilePage(userId: _customer.userId),
    ),
  );

  void _openProgress() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          MemberProgressPage(userId: _customer.userId, displayName: _name),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final c = _customer;
    return Scaffold(
      appBar: AppBar(title: Text(_name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            InkWell(
              onTap: _openProfile,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    UserAvatar(
                      url: c.avatarUrl,
                      initials: c.initials,
                      radius: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _name,
                            style: ts.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '@${c.username}',
                            style: ts.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          CustomerStatusChip(accepted: c.accepted),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: l10n.customersViewProfile,
                      child: Icon(
                        Icons.chevron_right,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_gone)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  l10n.customersNotFound,
                  style: TextStyle(color: cs.error),
                ),
              ),
            ListTile(
              enabled: c.accepted && !_gone,
              leading: const Icon(Icons.show_chart),
              title: Text(l10n.customersProgress),
              subtitle: Text(
                c.accepted
                    ? l10n.customersProgressSubtitle
                    : l10n.customersProgressLocked,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openProgress,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(l10n.customersYourClasses, style: ts.titleMedium),
            ),
            ..._buildClasses(),
            if (!_gone) ...[
              const Divider(height: 32),
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: cs.error),
                title: Text(
                  l10n.customersRemoveCustomer,
                  style: TextStyle(color: cs.error),
                ),
                onTap: _removeCustomer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildClasses() {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    if (_error != null) {
      return [
        SizedBox(
          height: 200,
          child: ScheduleError(message: _error!, onRetry: _load),
        ),
      ];
    }
    final series = _series;
    if (series == null) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: l10n.commonLoading,
            ),
          ),
        ),
      ];
    }
    if (series.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            l10n.customersNoClasses,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
      ];
    }
    return [for (final s in series) _classRow(s)];
  }

  Widget _classRow(ClassSeries s) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final status = _statusIn(s);
    final open = s.state == ClassSeriesState.active;
    final busy = _busy.contains(s.id) || _gone;

    final stateLabel = [
      status == null ? l10n.customersNotInClass : enrollmentLabel(l10n, status),
      if (!open) l10n.customersClassPaused,
    ].join(' · ');

    final Widget action = switch (status) {
      EnrollmentStatus.accepted => TextButton(
        onPressed: busy ? null : () => _removeFromClass(s),
        style: TextButton.styleFrom(foregroundColor: cs.error),
        child: Text(l10n.customersRemoveFromClass),
      ),
      EnrollmentStatus.pending => TextButton(
        onPressed: busy ? null : () => _cancelInvite(s),
        child: Text(l10n.customersCancelInvite),
      ),
      // Not in it, or declined: invite (again), but only to running classes.
      _ => FilledButton.tonal(
        onPressed: busy || !open ? null : () => _invite(s),
        child: Text(l10n.customersInvite),
      ),
    };

    return Opacity(
      opacity: open || status != null ? 1 : 0.6,
      child: ListTile(
        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${seriesScheduleSummary(context, s)}\n$stateLabel'),
        isThreeLine: true,
        trailing: action,
      ),
    );
  }
}
