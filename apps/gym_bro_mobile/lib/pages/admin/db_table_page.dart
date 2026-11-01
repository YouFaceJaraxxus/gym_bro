import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/admin_db.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'db_row_page.dart';

/// One table's rows: search any text column, narrow to exact column values
/// ([where], e.g. everything pointing at one row), page through, open a row
/// to edit or delete it, or add one.
class DbTablePage extends StatefulWidget {
  const DbTablePage({
    super.key,
    required this.table,
    required this.allTables,
    this.where = const {},
  });

  final DbTable table;

  /// The whole schema, for following foreign keys between tables.
  final List<DbTable> allTables;
  final Map<String, dynamic> where;

  @override
  State<DbTablePage> createState() => _DbTablePageState();
}

class _DbTablePageState extends State<DbTablePage> {
  static const _pageSize = 50;

  final _api = ApiService();
  final _query = TextEditingController();
  Timer? _debounce;

  late Map<String, dynamic> _where = {...widget.where};
  final List<Map<String, dynamic>> _rows = [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _request = 0;

  DbTable get t => widget.table;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      if (reset) _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final page = await _api.getDbRows(
        token,
        t.name,
        query: _query.text.trim(),
        where: _where,
        limit: _pageSize,
        offset: reset ? 0 : _rows.length,
      );
      if (!mounted || request != _request) return;
      setState(() {
        if (reset) _rows.clear();
        _rows.addAll(page.rows);
        _total = page.total;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openRow(Map<String, dynamic>? row) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DbRowPage(
          table: t,
          allTables: widget.allTables,
          pk: row == null ? null : t.pkOf(row),
          // New rows from a filtered list start with the filter's values.
          initialValues: row == null ? _where : const {},
        ),
      ),
    );
    if (changed == true) _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summaryCols = t.columns
        .where((c) => !t.primaryKey.contains(c.name) && !c.isLongText)
        .take(3)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(t.name, style: const TextStyle(fontFamily: 'monospace')),
      ),
      floatingActionButton: t.readOnly || t.primaryKey.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openRow(null),
              icon: const Icon(Icons.add),
              label: Text(l10n.adminDbAddRow),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _query,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.adminDbSearchRows,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(
                  const Duration(milliseconds: 350),
                  () => _load(reset: true),
                );
              },
            ),
          ),
          if (_where.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final e in _where.entries)
                    InputChip(
                      label: Text('${e.key} = ${dbCellText(e.value)}'),
                      onDeleted: () {
                        setState(() => _where = {..._where}..remove(e.key));
                        _load(reset: true);
                      },
                    ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.adminDbShowing(_rows.length, _total),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          Expanded(
            child: _error != null && _rows.isEmpty
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: () => _load(reset: true),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _rows.length + 1,
                      itemBuilder: (context, i) {
                        if (i == _rows.length) {
                          if (_loading) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (_rows.length < _total) {
                            return Center(
                              child: TextButton(
                                onPressed: _load,
                                child: Text(l10n.adminDbLoadMore),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        }
                        final row = _rows[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            t.labelOf(row),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            [
                              for (final c in summaryCols)
                                '${c.name}: ${dbCellText(row[c.name])}',
                            ].join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: t.primaryKey.isEmpty ? null : () => _openRow(row),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
