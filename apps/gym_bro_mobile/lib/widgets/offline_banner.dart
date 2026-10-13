import 'package:flutter/material.dart';
import '../l10n/l10n.dart';

import '../services/offline/offline_support.dart';

/// Slim banner shown while the app is offline; collapses to nothing otherwise.
/// Place it at the top of a page body (e.g. in a Column above the content).
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  @override
  void initState() {
    super.initState();
    OfflineSupport.ensureStarted();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return ValueListenableBuilder<bool>(
      valueListenable: ConnectivityService.instance.online,
      builder: (context, online, _) => ValueListenableBuilder<int>(
        valueListenable: OfflineSupport.outbox.pending,
        builder: (context, pending, _) => AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: online
              ? const SizedBox(width: double.infinity)
              : Semantics(
                  liveRegion: true,
                  child: Material(
                    color: scheme.inverseSurface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.cloud_off,
                            size: 16,
                            color: scheme.onInverseSurface,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pending > 0
                                  ? context.l10n.shellOfflinePending(pending)
                                  : context.l10n.shellOffline,
                              style: text.bodySmall?.copyWith(
                                color: scheme.onInverseSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
