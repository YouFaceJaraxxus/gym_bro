import 'package:flutter_timezone/flutter_timezone.dart';

String? _cached;

/// The device's IANA time zone (e.g. "Europe/Belgrade"), or null when the
/// platform can't tell (the server then falls back to UTC or the viewer's
/// zone). Cached after the first successful lookup.
Future<String?> deviceTimezone() async {
  if (_cached != null) return _cached;
  try {
    final tz = await FlutterTimezone.getLocalTimezone();
    return _cached = tz.identifier;
  } catch (_) {
    return null;
  }
}
