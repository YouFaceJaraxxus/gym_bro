import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/settings_service.dart';
import 'body_metric_labels.dart';

/// A progress photo from its signed URL, with a quiet placeholder while it
/// loads and when it can't.
class ProgressPhotoImage extends StatelessWidget {
  final ProgressPhoto photo;
  final BoxFit fit;

  /// Tests: serve images without the network.
  @visibleForTesting
  static ImageProvider Function(ProgressPhoto photo)? debugImageProvider;

  const ProgressPhotoImage({super.key, required this.photo, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget placeholder(IconData icon) => ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(child: Icon(icon, color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
    );
    final provider = debugImageProvider?.call(photo) ?? (photo.url == null ? null : NetworkImage(photo.url!));
    if (provider == null) return placeholder(Icons.broken_image_outlined);
    return Image(
      image: provider,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => sync || frame != null
          ? child
          : placeholder(Icons.photo_outlined),
      errorBuilder: (_, _, _) => placeholder(Icons.broken_image_outlined),
    );
  }
}

/// "Only you can see these" banner for the photos section.
class ProgressPhotosPrivacyNote extends StatelessWidget {
  const ProgressPhotosPrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 20, color: cs.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${l10n.bodyPhotosPrivate} ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: l10n.bodyPhotosPrivateDetail),
                ],
              ),
              style: text.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small pill over a photo: "Side · 80.4 kg".
class ProgressPhotoBadge extends StatelessWidget {
  final String label;

  const ProgressPhotoBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// "Oct 12, 2026 · Front · 80.4 kg"
String progressPhotoCaption(ProgressPhoto p, AppLocalizations l10n, String locale) => [
  DateFormat.yMMMd(locale).format(p.takenOn),
  progressPoseLabel(p.pose, l10n),
  if (p.weightKg != null) SettingsService.instance.formatWeight(p.weightKg!),
].join(' · ');
