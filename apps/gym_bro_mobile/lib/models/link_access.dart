/// Whether the viewer can still open something a record links to (a plan
/// entry's routine, a shared post's source …), as the API reports it:
/// `"ok"`, `"private"` (exists, but no access — e.g. a private routine they
/// left) or `"unavailable"` (deleted). Null from the API: no such link.
enum LinkAccess {
  ok,
  private,
  unavailable;

  static LinkAccess? tryParse(Object? v) => switch (v) {
    'ok' => ok,
    'private' => private,
    'unavailable' => unavailable,
    _ => null,
  };

  bool get canOpen => this == ok;
}
