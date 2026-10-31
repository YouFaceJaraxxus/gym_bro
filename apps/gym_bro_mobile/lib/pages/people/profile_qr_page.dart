import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../models/post.dart';
import '../../models/shared_content.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/share_sheet.dart';
import 'user_profile_page.dart';

/// `gymbroo://u/<username>`: what a profile QR code holds, and the deep link
/// that opens the profile in the app.
Uri profileLink(String username) => Uri(scheme: 'gymbroo', host: 'u', path: '/$username');

/// The username in a profile link (`gymbroo://u/<username>`), else null.
String? usernameFromProfileLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.scheme != 'gymbroo' || uri.host != 'u') return null;
  final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
  return RegExp(r'^[a-zA-Z0-9._]{3,30}$').hasMatch(name) ? name : null;
}

/// Opens the profile of [username] (from a scanned code or a link); a
/// SnackBar when there's no such person.
Future<void> openProfileByUsername(BuildContext context, String username, {bool replace = false}) async {
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final token = await AuthManager.instance.getValidToken();
    final profile = await ApiService().getProfileByUsername(token, username);
    final route = MaterialPageRoute<void>(builder: (_) => UserProfilePage(userId: profile.id));
    replace ? unawaited(navigator.pushReplacement(route)) : unawaited(navigator.push(route));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.profileExtrasQrNotFound(username))));
  }
}

/// My profile as a QR code (Instagram's "QR code"): others scan it with this
/// page's scanner or their camera to open my profile.
class ProfileQrPage extends StatelessWidget {
  const ProfileQrPage({super.key, required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final link = profileLink(profile.username).toString();
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileExtrasQrTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: cs.shadow.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    Semantics(
                      label: l10n.profileExtrasQrSemantics(profile.username),
                      child: QrImageView(
                        data: link,
                        size: 220,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.black),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.circle,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '@${profile.username}',
                      style: text.titleMedium?.copyWith(color: Colors.black, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.profileExtrasQrHint,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: () => showShareSheet(
                context,
                ShareRequest.of(
                  ShareKind.user,
                  profile.id,
                  title: profile.fullName.isNotEmpty ? profile.fullName : '@${profile.username}',
                  preview: PostAttachment({'avatar_url': ?profile.avatarUrl}),
                ),
              ),
              icon: const Icon(Icons.send_outlined),
              label: Text(l10n.shareProfileAction),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileExtrasQrLinkCopied)));
              },
              icon: const Icon(Icons.link),
              label: Text(l10n.profileExtrasQrCopyLink),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const ProfileQrScannerPage())),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n.profileExtrasQrScan),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scans someone's profile QR code and opens their profile.
class ProfileQrScannerPage extends StatefulWidget {
  const ProfileQrScannerPage({super.key});

  @override
  State<ProfileQrScannerPage> createState() => _ProfileQrScannerPageState();
}

class _ProfileQrScannerPageState extends State<ProfileQrScannerPage> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handled = false;
  String? _lastInvalid;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      final username = usernameFromProfileLink(raw);
      if (username != null) {
        _handled = true;
        unawaited(_controller.stop());
        unawaited(openProfileByUsername(context, username, replace: true));
        return;
      }
      if (raw != _lastInvalid) {
        _lastInvalid = raw;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.l10n.profileExtrasQrNotAProfile)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileExtrasQrScan)),
      body: MobileScanner(
        controller: _controller,
        onDetect: _onDetect,
        errorBuilder: (context, error) => ColoredBox(
          color: cs.surface,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.no_photography_outlined, size: 56, color: cs.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? l10n.businessCheckInCameraDeniedMessage
                        : l10n.profileExtrasQrCameraUnavailable,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(onPressed: () => unawaited(_controller.start()), child: Text(l10n.commonRetry)),
                ],
              ),
            ),
          ),
        ),
        overlayBuilder: (context, constraints) => Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ),
    );
  }
}
