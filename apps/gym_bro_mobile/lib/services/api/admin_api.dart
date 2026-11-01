part of '../api_service.dart';

/// The super-user database console (/admin/tables): browse and edit any table.
/// [pk] and [where] maps are sent as JSON in the query string.
extension AdminApi on ApiService {
  String _json(Map<String, dynamic> m) => Uri.encodeQueryComponent(jsonEncode(m));

  /// GET /admin/tables — every table with its columns, keys and row count.
  Future<List<DbTable>> getDbTables(String token) async {
    final r = await _client.get(Uri.parse('$_base/admin/tables'), headers: _headers(token));
    _check(r);
    return (jsonDecode(r.body) as List)
        .map((e) => DbTable.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// GET /admin/tables/:t — a page of rows: free text [query], exact
  /// [where] filters, newest first unless [orderBy] is given.
  Future<DbRows> getDbRows(
    String token,
    String table, {
    String query = '',
    Map<String, dynamic> where = const {},
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool ascending = false,
  }) async {
    final params = [
      'limit=$limit',
      'offset=$offset',
      if (query.isNotEmpty) 'q=${Uri.encodeQueryComponent(query)}',
      if (where.isNotEmpty) 'where=${_json(where)}',
      if (orderBy != null) 'order=$orderBy',
      if (orderBy != null) 'dir=${ascending ? 'asc' : 'desc'}',
    ];
    final r = await _client.get(
      Uri.parse('$_base/admin/tables/$table?${params.join('&')}'),
      headers: _headers(token),
    );
    _check(r);
    return DbRows.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /admin/tables/:t/row — the row and, per foreign key pointing at it,
  /// how many rows do.
  Future<({Map<String, dynamic> row, List<DbForeignKey> referencedBy})> getDbRow(
    String token,
    String table,
    Map<String, dynamic> pk,
  ) async {
    final r = await _client.get(
      Uri.parse('$_base/admin/tables/$table/row?pk=${_json(pk)}'),
      headers: _headers(token),
    );
    _check(r);
    final d = jsonDecode(r.body) as Map<String, dynamic>;
    return (
      row: d['row'] as Map<String, dynamic>,
      referencedBy: (d['referenced_by'] as List? ?? [])
          .map((e) => DbForeignKey.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// POST /admin/tables/:t — inserts; omitted columns take their defaults.
  Future<Map<String, dynamic>> insertDbRow(
    String token,
    String table,
    Map<String, dynamic> values,
  ) async {
    final r = await _client.post(
      Uri.parse('$_base/admin/tables/$table'),
      headers: _headers(token),
      body: jsonEncode({'values': values}),
    );
    _check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// PATCH /admin/tables/:t/row — sets [values] on the row.
  Future<Map<String, dynamic>> updateDbRow(
    String token,
    String table,
    Map<String, dynamic> pk,
    Map<String, dynamic> values,
  ) async {
    final r = await _client.patch(
      Uri.parse('$_base/admin/tables/$table/row?pk=${_json(pk)}'),
      headers: _headers(token),
      body: jsonEncode({'values': values}),
    );
    _check(r);
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// GET /admin/tables/:t/row/impact — what deleting the row affects.
  Future<DbImpact> getDbDeleteImpact(
    String token,
    String table,
    Map<String, dynamic> pk,
  ) async {
    final r = await _client.get(
      Uri.parse('$_base/admin/tables/$table/row/impact?pk=${_json(pk)}'),
      headers: _headers(token),
    );
    _check(r);
    return DbImpact.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// DELETE /admin/tables/:t/row. [expected] is the number of rows the admin
  /// confirmed (DbImpact.total); the API refuses if it changed since. With
  /// [force], rows that block the delete go too.
  Future<void> deleteDbRow(
    String token,
    String table,
    Map<String, dynamic> pk, {
    required int expected,
    bool force = false,
  }) async {
    final r = await _client.delete(
      Uri.parse('$_base/admin/tables/$table/row?pk=${_json(pk)}'),
      headers: _headers(token),
      body: jsonEncode({'expected': expected, 'force': force}),
    );
    if (r.statusCode >= 400 && r.statusCode != 204) _check(r);
  }
}
