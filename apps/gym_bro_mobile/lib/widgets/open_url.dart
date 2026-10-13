import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [rawUrl] in an external app (browser / YouTube). Adds `https://` when
/// the scheme is missing and shows a SnackBar if nothing can handle it.
Future<void> openExternalUrl(BuildContext context, String rawUrl) async {
  final trimmed = rawUrl.trim();
  final withScheme =
      trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(withScheme);
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  if (uri != null && uri.host.isNotEmpty) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open $trimmed')),
    );
  }
}
