part of '../api_service.dart';

/// Gym Bro Wrapped, my yearly recap.
extension WrappedApi on ApiService {
  /// GET /wrapped — the years with (or soon with) a recap.
  Future<WrappedIndex> getWrappedIndex(String token, {String? tz}) async {
    final q = tz == null ? '' : '?tz=${Uri.encodeQueryComponent(tz)}';
    final r = await _client.get(Uri.parse('$_base/wrapped$q'), headers: _headers(token));
    _check(r);
    return WrappedIndex.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  /// GET /wrapped/:year — the recap, or `available: false` until it opens.
  /// [preview] opens the current year early (super users only).
  Future<Wrapped> getWrapped(String token, int year, {String? tz, bool preview = false}) async {
    final q = [
      if (tz != null) 'tz=${Uri.encodeQueryComponent(tz)}',
      if (preview) 'preview=1',
    ].join('&');
    final r = await _client.get(Uri.parse('$_base/wrapped/$year${q.isEmpty ? '' : '?$q'}'), headers: _headers(token));
    _check(r);
    return Wrapped.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }
}
