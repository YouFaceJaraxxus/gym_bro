import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/admin_db.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../business/business_review_page.dart';
import 'db_table_page.dart';

/// Super users: every table in the database, with shortcuts to the ones
/// they open most and to verifying businesses. Tap a table to browse, edit,
/// add and delete its rows.
class DbConsolePage extends StatefulWidget {
  const DbConsolePage({super.key});

  @override
  State<DbConsolePage> createState() => _DbConsolePageState();
}

class _DbConsolePageState extends State<DbConsolePage> {
  final _api = ApiService();
  final _filter = TextEditingController();

  List<DbTable>? _tables;
  String? _error;

  static const _shortcuts = [
    ('users', Icons.person_outline),
    ('business', Icons.storefront_outlined),
    ('business_member', Icons.badge_outlined),
    ('membership', Icons.card_membership_outlined),
    ('post', Icons.dynamic_feed_outlined),
    ('admin_audit_log', Icons.history),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await AuthManager.instance.getValidToken();
      final tables = await _api.getDbTables(token);
      if (mounted) {
        setState(() {
          _tables = tables;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  Future<void> _open(DbTable t) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DbTablePage(table: t, allTables: _tables!)),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tables = _tables;
    final q = _filter.text.trim().toLowerCase();
    final shown = tables?.where((t) => t.name.contains(q)).toList() ?? [];
    final byName = {for (final t in tables ?? <DbTable>[]) t.name: t};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminDbTitle)),
      body: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: Text(l10n.commonRetry)),
                ],
              ),
            )
          : tables == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  Card(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_outlined,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.adminDbWarning,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.verified_outlined),
                    title: Text(l10n.rolesMenuReviewQueue),
                    subtitle: Text(l10n.adminDbReviewSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BusinessReviewPage()),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final (name, icon) in _shortcuts)
                          if (byName[name] case final t?)
                            ActionChip(
                              avatar: Icon(icon, size: 18),
                              label: Text('$name · ${t.rowCount}'),
                              onPressed: () => _open(t),
                            ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: TextField(
                      controller: _filter,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: l10n.adminDbFilterTables(tables.length),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  for (final t in shown)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        t.readOnly ? Icons.lock_outline : Icons.table_chart_outlined,
                      ),
                      title: Text(t.name, style: const TextStyle(fontFamily: 'monospace')),
                      subtitle: Text(
                        l10n.adminDbTableSummary(t.rowCount, t.columns.length),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _open(t),
                    ),
                ],
              ),
            ),
    );
  }
}
