import 'dart:convert';

/// The super-user database console (/admin/tables): the schema as Postgres
/// reports it, so every table can be browsed and edited generically.

class DbColumn {
  final String name;

  /// Postgres type as `format_type` prints it ("uuid", "text[]",
  /// "timestamp with time zone", "notification_type[]", …).
  final String type;

  /// 'enum', 'array', 'base' or 'other'.
  final String kind;
  final List<String>? enumValues;
  final bool nullable;
  final bool hasDefault;
  final bool generated;

  const DbColumn({
    required this.name,
    required this.type,
    required this.kind,
    this.enumValues,
    required this.nullable,
    required this.hasDefault,
    required this.generated,
  });

  bool get isBool => type == 'boolean';
  bool get isJson => type == 'json' || type == 'jsonb';
  bool get isArray => type.endsWith('[]');
  bool get isEnum => kind == 'enum' && !isArray;
  bool get isNumber => RegExp(
    r'^(integer|bigint|smallint|numeric|real|double precision)',
  ).hasMatch(type);
  bool get isLongText => type == 'text' || isJson || isArray;

  factory DbColumn.fromJson(Map<String, dynamic> j) => DbColumn(
    name: j['name'] as String,
    type: j['type'] as String,
    kind: j['kind'] as String? ?? 'base',
    enumValues: (j['enum_values'] as List?)?.cast<String>(),
    nullable: j['nullable'] as bool? ?? true,
    hasDefault: j['has_default'] as bool? ?? false,
    generated: j['generated'] as bool? ?? false,
  );
}

class DbForeignKey {
  final String name;
  final String table;
  final List<String> columns;
  final String refTable;
  final List<String> refColumns;

  /// cascade, set_null, set_default, restrict, no_action.
  final String onDelete;

  /// Rows pointing at the current row (GET row only).
  final int count;

  const DbForeignKey({
    required this.name,
    required this.table,
    required this.columns,
    required this.refTable,
    required this.refColumns,
    required this.onDelete,
    this.count = 0,
  });

  factory DbForeignKey.fromJson(Map<String, dynamic> j) => DbForeignKey(
    name: j['name'] as String,
    table: j['table'] as String,
    columns: (j['columns'] as List).cast<String>(),
    refTable: j['ref_table'] as String,
    refColumns: (j['ref_columns'] as List).cast<String>(),
    onDelete: j['on_delete'] as String? ?? 'no_action',
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

class DbTable {
  final String name;
  final List<DbColumn> columns;
  final List<String> primaryKey;
  final List<DbForeignKey> foreignKeys;
  final List<DbForeignKey> referencedBy;
  final int rowCount;
  final bool readOnly;

  const DbTable({
    required this.name,
    required this.columns,
    required this.primaryKey,
    required this.foreignKeys,
    required this.referencedBy,
    required this.rowCount,
    required this.readOnly,
  });

  DbColumn? column(String name) {
    for (final c in columns) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// The foreign key a single column belongs to, if any.
  DbForeignKey? foreignKeyFor(String column) {
    for (final fk in foreignKeys) {
      if (fk.columns.length == 1 && fk.columns.first == column) return fk;
    }
    return null;
  }

  /// The row's primary key as the console addresses it.
  Map<String, dynamic> pkOf(Map<String, dynamic> row) => {
    for (final k in primaryKey) k: row[k],
  };

  static const _labelColumns = [
    'name',
    'title',
    'username',
    'email',
    'label',
    'body',
    'content',
    'caption',
    'note',
    'tag',
  ];

  /// A human line for a row: its name-ish column, or its key.
  String labelOf(Map<String, dynamic> row) {
    for (final c in _labelColumns) {
      final v = row[c];
      if (v is String && v.trim().isNotEmpty) {
        final last = row['last_name'];
        return c == 'name' && last is String ? '$v $last' : v;
      }
    }
    return primaryKey.map((k) => '${row[k]}').join(' · ');
  }

  factory DbTable.fromJson(Map<String, dynamic> j) => DbTable(
    name: j['name'] as String,
    columns: (j['columns'] as List)
        .map((e) => DbColumn.fromJson(e as Map<String, dynamic>))
        .toList(),
    primaryKey: (j['primary_key'] as List? ?? []).cast<String>(),
    foreignKeys: (j['foreign_keys'] as List? ?? [])
        .map((e) => DbForeignKey.fromJson(e as Map<String, dynamic>))
        .toList(),
    referencedBy: (j['referenced_by'] as List? ?? [])
        .map((e) => DbForeignKey.fromJson(e as Map<String, dynamic>))
        .toList(),
    rowCount: (j['row_count'] as num?)?.toInt() ?? 0,
    readOnly: j['read_only'] as bool? ?? false,
  );
}

/// A page of rows.
class DbRows {
  final int total;
  final List<Map<String, dynamic>> rows;

  const DbRows({required this.total, required this.rows});

  factory DbRows.fromJson(Map<String, dynamic> j) => DbRows(
    total: (j['total'] as num?)?.toInt() ?? 0,
    rows: (j['rows'] as List).cast<Map<String, dynamic>>(),
  );
}

/// One table's rows affected by a delete, reached through foreign key [via].
class DbEffect {
  final String table;
  final String via;
  final List<String> columns;
  final String action;
  final int count;

  /// 1 = points straight at the row; deeper = through other deleted rows.
  final int depth;

  const DbEffect({
    required this.table,
    required this.via,
    required this.columns,
    required this.action,
    required this.count,
    required this.depth,
  });

  factory DbEffect.fromJson(Map<String, dynamic> j) => DbEffect(
    table: j['table'] as String,
    via: j['via'] as String,
    columns: (j['columns'] as List).cast<String>(),
    action: j['action'] as String,
    count: (j['count'] as num).toInt(),
    depth: (j['depth'] as num?)?.toInt() ?? 1,
  );
}

/// What deleting a row does: rows deleted with it, columns emptied, and rows
/// that stop it (which a forced delete removes too).
class DbImpact {
  final List<DbEffect> deleted;
  final List<DbEffect> nulled;
  final List<DbEffect> blocking;

  /// Rows a forced delete removes besides the row itself.
  final int forcedRows;

  const DbImpact({
    required this.deleted,
    required this.nulled,
    required this.blocking,
    required this.forcedRows,
  });

  int get cascadedRows => deleted.fold(0, (s, e) => s + e.count);

  /// What the API expects as `expected` (includes the row itself).
  int total({required bool force}) => (force ? forcedRows : cascadedRows) + 1;

  static List<DbEffect> _list(dynamic v) => (v as List? ?? [])
      .map((e) => DbEffect.fromJson(e as Map<String, dynamic>))
      .toList();

  factory DbImpact.fromJson(Map<String, dynamic> j) => DbImpact(
    deleted: _list(j['deleted']),
    nulled: _list(j['nulled']),
    blocking: _list(j['blocking']),
    forcedRows: (j['forced_rows'] as num?)?.toInt() ?? 0,
  );
}

/// A cell as text for display and editing (JSON for non-strings).
String dbCellText(dynamic v) {
  if (v == null) return '';
  if (v is String) return v;
  return jsonEncode(v);
}
