import 'dart:convert';

import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/admin_db.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../typed_confirm_dialog.dart';
import 'db_table_page.dart';

/// One row of any table, as a form: edit and save, or add a new row when
/// [pk] is null. Foreign key fields open the row they point at; "Referenced
/// by" lists what points here. Deleting shows everything it affects first
/// and needs the table name typed. Pops true when something changed.
class DbRowPage extends StatefulWidget {
  const DbRowPage({
    super.key,
    required this.table,
    required this.allTables,
    this.pk,
    this.initialValues = const {},
  });

  final DbTable table;
  final List<DbTable> allTables;
  final Map<String, dynamic>? pk;

  /// Starting values for a new row (e.g. the filter it was added from).
  final Map<String, dynamic> initialValues;

  @override
  State<DbRowPage> createState() => _DbRowPageState();
}

class _DbRowPageState extends State<DbRowPage> {
  final _api = ApiService();
  final _formKey = GlobalKey<FormState>();

  Map<String, dynamic> _original = {};
  List<DbForeignKey> _referencedBy = [];
  final Map<String, TextEditingController> _text = {};
  final Map<String, dynamic> _choice = {}; // booleans and enums
  final Set<String> _nulls = {};
  late Map<String, dynamic>? _pk = widget.pk;

  bool _loading = true;
  bool _saving = false;
  bool _changed = false;
  String? _error;

  DbTable get t => widget.table;
  bool get _isNew => _pk == null;
  bool get _editable => !t.readOnly;

  @override
  void initState() {
    super.initState();
    if (_isNew) {
      _fill(widget.initialValues, isNew: true);
      _loading = false;
    } else {
      _load();
    }
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Map<String, dynamic> row, {bool isNew = false}) {
    _original = row;
    _nulls.clear();
    for (final c in t.columns) {
      final v = row[c.name];
      if (!isNew && v == null) _nulls.add(c.name);
      if (c.isBool || c.isEnum) {
        _choice[c.name] = v;
      } else {
        final text = c.isJson && v != null && v is! String
            ? const JsonEncoder.withIndent('  ').convert(v)
            : dbCellText(v);
        (_text[c.name] ??= TextEditingController()).text = text;
      }
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final res = await _api.getDbRow(token, t.name, _pk!);
      if (!mounted) return;
      setState(() {
        _fill(res.row);
        _referencedBy = res.referencedBy;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  /// The column's value from the form, or [_Invalid] with a message.
  Object? _valueOf(DbColumn c) {
    if (_nulls.contains(c.name)) return null;
    if (c.isBool || c.isEnum) return _choice[c.name];
    final raw = _text[c.name]!.text;
    if (c.isJson || c.isArray) {
      if (raw.trim().isEmpty) return null;
      try {
        final v = jsonDecode(raw);
        if (c.isArray && v is! List) return _Invalid(context.l10n.adminDbNeedsJsonArray);
        return v;
      } on FormatException {
        return _Invalid(context.l10n.adminDbInvalidJson);
      }
    }
    if (raw.isEmpty && c.nullable) return null;
    return raw;
  }

  /// Only what differs from the loaded row (all filled fields for a new row).
  Map<String, dynamic>? _changes() {
    final out = <String, dynamic>{};
    for (final c in t.columns) {
      if (c.generated) continue;
      final v = _valueOf(c);
      if (v is _Invalid) return null;
      if (_isNew) {
        // Leave empty columns to their defaults.
        final empty = v == null || (v is String && v.isEmpty);
        if (empty && (c.hasDefault || c.nullable) && !_nulls.contains(c.name)) continue;
        out[c.name] = v;
      } else if (jsonEncode(v) != jsonEncode(_original[c.name])) {
        // Compare as text so "5" (form) matches 5 (loaded number).
        final was = _original[c.name];
        if (v is String && was != null && v == dbCellText(was)) continue;
        out[c.name] = v;
      }
    }
    return out;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final changes = _changes();
    if (changes == null) return;
    if (changes.isEmpty && !_isNew) {
      Navigator.pop(context, _changed);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final row = _isNew
          ? await _api.insertDbRow(token, t.name, changes)
          : await _api.updateDbRow(token, t.name, _pk!, changes);
      if (!mounted) return;
      _changed = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isNew ? context.l10n.adminDbInserted : context.l10n.adminDbSaved)),
      );
      setState(() {
        _pk = t.pkOf(row);
        _saving = false;
      });
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    DbImpact impact;
    try {
      final token = await AuthManager.instance.getValidToken();
      impact = await _api.getDbDeleteImpact(token, t.name, _pk!);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (!mounted) return;

    final force = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ImpactSheet(table: t.name, impact: impact),
    );
    if (force == null || !mounted) return;

    final total = impact.total(force: force);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => TypedConfirmDialog(
        title: l10n.adminDbDeleteTitle(total),
        message: t.name == 'users'
            ? '${l10n.adminDbDeleteMessage(t.name)}\n\n${l10n.adminDbDeleteUserNote}'
            : l10n.adminDbDeleteMessage(t.name),
        confirmText: t.name,
        actionLabel: l10n.adminDbDeleteAction(total),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteDbRow(token, t.name, _pk!, expected: total, force: force);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.adminDbDeleted(total))),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _saving = false;
        });
      }
    }
  }

  /// Opens what a foreign key column points at.
  void _follow(DbForeignKey fk, dynamic value) {
    final parent = widget.allTables.where((x) => x.name == fk.refTable).firstOrNull;
    if (parent == null || value == null) return;
    final where = {fk.refColumns.first: value};
    final byPk = parent.primaryKey.length == 1 && parent.primaryKey.first == fk.refColumns.first;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => byPk
            ? DbRowPage(table: parent, allTables: widget.allTables, pk: where)
            : DbTablePage(table: parent, allTables: widget.allTables, where: where),
      ),
    );
  }

  /// Opens the rows of [fk.table] pointing at this row.
  Future<void> _openReferencing(DbForeignKey fk) async {
    final child = widget.allTables.where((x) => x.name == fk.table).firstOrNull;
    if (child == null) return;
    final where = {
      for (var i = 0; i < fk.columns.length; i++) fk.columns[i]: _original[fk.refColumns[i]],
    };
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DbTablePage(table: child, allTables: widget.allTables, where: where),
      ),
    );
    if (!_isNew) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isNew ? l10n.adminDbNewRow(t.name) : t.labelOf(_original),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (!_isNew && _editable)
              IconButton(
                tooltip: l10n.adminDbDeleteRow,
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                onPressed: _saving ? null : _delete,
              ),
          ],
        ),
        floatingActionButton: _editable && !_loading
            ? FloatingActionButton.extended(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(_isNew ? l10n.adminDbInsert : l10n.adminDbSave),
              )
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    Text(
                      t.name,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(fontFamily: 'monospace'),
                    ),
                    if (_error != null)
                      Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    for (final c in t.columns) _field(c),
                    if (_referencedBy.any((r) => r.count > 0)) ...[
                      const Divider(height: 32),
                      Text(l10n.adminDbReferencedBy, style: Theme.of(context).textTheme.titleSmall),
                      for (final fk in _referencedBy.where((r) => r.count > 0))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.subdirectory_arrow_right),
                          title: Text('${fk.table}.${fk.columns.join(', ')}'),
                          subtitle: Text(l10n.adminDbRefSummary(fk.count, _actionLabel(l10n, fk.onDelete))),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openReferencing(fk),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _field(DbColumn c) {
    final l10n = context.l10n;
    final isPk = t.primaryKey.contains(c.name);
    final readOnly = !_editable || c.generated || (isPk && !_isNew);
    final isNull = _nulls.contains(c.name);
    final fk = t.foreignKeyFor(c.name);
    final label = '${c.name}${c.nullable ? '' : ' *'}';
    final helper = [
      c.type,
      if (c.hasDefault && _isNew) l10n.adminDbHasDefault,
      if (fk != null) '→ ${fk.refTable}.${fk.refColumns.join(', ')}',
    ].join(' · ');

    Widget input;
    if (c.isBool) {
      input = DropdownButtonFormField<bool?>(
        initialValue: isNull ? null : _choice[c.name] as bool?,
        decoration: InputDecoration(labelText: label, helperText: helper),
        items: [
          if (c.nullable || _isNew) const DropdownMenuItem(value: null, child: Text('—')),
          const DropdownMenuItem(value: true, child: Text('true')),
          const DropdownMenuItem(value: false, child: Text('false')),
        ],
        onChanged: readOnly ? null : (v) => setState(() => _choice[c.name] = v),
      );
    } else if (c.isEnum) {
      input = DropdownButtonFormField<String?>(
        initialValue: _choice[c.name] as String?,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, helperText: helper),
        items: [
          if (c.nullable || _isNew) const DropdownMenuItem(value: null, child: Text('—')),
          for (final v in c.enumValues ?? const <String>[]) DropdownMenuItem(value: v, child: Text(v)),
        ],
        onChanged: readOnly ? null : (v) => setState(() => _choice[c.name] = v),
      );
    } else {
      input = TextFormField(
        controller: _text[c.name],
        readOnly: readOnly || isNull,
        minLines: 1,
        maxLines: c.isLongText ? 8 : 1,
        keyboardType: c.isNumber ? const TextInputType.numberWithOptions(decimal: true, signed: true) : null,
        style: c.isJson || c.isArray || c.type == 'uuid' ? const TextStyle(fontFamily: 'monospace', fontSize: 13) : null,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          hintText: isNull ? 'NULL' : null,
          suffixIcon: fk != null && !isNull && (_text[c.name]?.text.isNotEmpty ?? false)
              ? IconButton(
                  tooltip: l10n.adminDbOpenReferenced(fk.refTable),
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _follow(fk, _text[c.name]!.text),
                )
              : null,
        ),
        validator: (v) {
          if (isNull || readOnly) return null;
          if ((v ?? '').isEmpty && !c.nullable && !(c.hasDefault && _isNew)) return l10n.commonRequired;
          final value = _valueOf(c);
          return value is _Invalid ? value.message : null;
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: input),
          // Nullable columns can be set to NULL explicitly.
          if (c.nullable && !readOnly && !c.isBool && !c.isEnum)
            IconButton(
              tooltip: isNull ? l10n.adminDbSetValue : l10n.adminDbSetNull,
              isSelected: isNull,
              icon: const Icon(Icons.block_outlined),
              selectedIcon: const Icon(Icons.block),
              onPressed: () => setState(() => isNull ? _nulls.remove(c.name) : _nulls.add(c.name)),
            ),
        ],
      ),
    );
  }
}

String _actionLabel(AppLocalizations l10n, String action) => switch (action) {
  'cascade' => l10n.adminDbOnDeleteCascade,
  'set_null' || 'set_default' => l10n.adminDbOnDeleteSetNull,
  _ => l10n.adminDbOnDeleteRestrict,
};

class _Invalid {
  const _Invalid(this.message);
  final String message;
}

/// What a delete affects. Pops false for a plain delete, true to also delete
/// the rows in the way, or null to cancel.
class _ImpactSheet extends StatefulWidget {
  const _ImpactSheet({required this.table, required this.impact});

  final String table;
  final DbImpact impact;

  @override
  State<_ImpactSheet> createState() => _ImpactSheetState();
}

class _ImpactSheetState extends State<_ImpactSheet> {
  bool _force = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final i = widget.impact;
    final blocked = i.blocking.isNotEmpty;

    Widget section(String title, List<DbEffect> effects, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color)),
        ),
        for (final e in effects)
          Padding(
            padding: EdgeInsets.only(left: 12.0 * (e.depth - 1), top: 2, bottom: 2),
            child: Text(
              '${e.depth > 1 ? '↳ ' : ''}${e.count} × ${e.table}  (${e.columns.join(', ')})',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
      ],
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(l10n.adminDbImpactTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              i.deleted.isEmpty && i.nulled.isEmpty && !blocked
                  ? l10n.adminDbImpactNothing
                  : l10n.adminDbImpactIntro,
            ),
            if (i.deleted.isNotEmpty) section(l10n.adminDbImpactDeleted(i.cascadedRows), i.deleted, cs.error),
            if (i.nulled.isNotEmpty) section(l10n.adminDbImpactNulled, i.nulled, cs.tertiary),
            if (blocked) ...[
              section(l10n.adminDbImpactBlocking, i.blocking, cs.error),
              const SizedBox(height: 8),
              Card(
                color: cs.errorContainer,
                child: SwitchListTile(
                  value: _force,
                  onChanged: (v) => setState(() => _force = v),
                  title: Text(l10n.adminDbForce, style: TextStyle(color: cs.onErrorContainer)),
                  subtitle: Text(
                    l10n.adminDbForceHint(i.forcedRows),
                    style: TextStyle(color: cs.onErrorContainer),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: cs.error, foregroundColor: cs.onError),
                  onPressed: blocked && !_force ? null : () => Navigator.pop(context, _force),
                  child: Text(l10n.adminDbDeleteAction(i.total(force: _force))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
