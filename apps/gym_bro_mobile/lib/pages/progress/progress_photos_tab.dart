import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../services/settings_service.dart';
import 'add_progress_photo_sheet.dart';
import 'body_metric_labels.dart';
import 'photo_compare_page.dart';
import 'progress_format.dart';
import 'progress_photo_viewer.dart';
import 'progress_photo_widgets.dart';

/// My progress photos. Only ever shown for the signed-in user's own
/// progress: the API has no way to read anyone else's.
class ProgressPhotosTab extends StatefulWidget {
  const ProgressPhotosTab({super.key});

  @override
  State<ProgressPhotosTab> createState() => _ProgressPhotosTabState();
}

class _ProgressPhotosTabState extends State<ProgressPhotosTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  List<ProgressPhoto> _photos = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final photos = await _api.getProgressPhotos(token);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _add(ProgressPose? pose) async {
    try {
      final photo = await addProgressPhotoFlow(context, pose: pose);
      if (photo != null && mounted) setState(() => _photos = [photo, ..._photos]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _open(List<ProgressPhoto> shown, int index) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProgressPhotoViewerPage(photos: shown, initialIndex: index, allPhotos: _photos),
      ),
    );
    if (changed == true && mounted) _load();
  }

  void _compare() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => PhotoComparePage(photos: _photos)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading && _photos.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _photos.isEmpty) return ProgressErrorView(message: _error!, onRetry: _load);
    return ProgressPhotosView(
      photos: _photos,
      onRefresh: _load,
      onAdd: _add,
      onOpen: _open,
      onCompare: _compare,
    );
  }
}

/// Privacy note, pose filter, Add / Compare, and the photos in a grid grouped
/// by month (newest first).
class ProgressPhotosView extends StatefulWidget {
  final List<ProgressPhoto> photos;
  final Future<void> Function() onRefresh;

  /// Adds a photo; the pose filter, when one is on, preselects the pose.
  final ValueChanged<ProgressPose?> onAdd;
  final void Function(List<ProgressPhoto> shown, int index) onOpen;
  final VoidCallback onCompare;

  const ProgressPhotosView({
    super.key,
    required this.photos,
    required this.onRefresh,
    required this.onAdd,
    required this.onOpen,
    required this.onCompare,
  });

  @override
  State<ProgressPhotosView> createState() => _ProgressPhotosViewState();
}

class _ProgressPhotosViewState extends State<ProgressPhotosView> {
  ProgressPose? _pose;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final all = widget.photos;

    if (all.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const ProgressPhotosPrivacyNote(),
            ProgressEmptyView(
              icon: Icons.photo_camera_outlined,
              title: l10n.bodyPhotosEmptyTitle,
              message: l10n.bodyPhotosEmptyMessage,
              action: FilledButton.icon(
                onPressed: () => widget.onAdd(null),
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(l10n.bodyPhotoAdd),
              ),
            ),
          ],
        ),
      );
    }

    final shown = [for (final p in all) if (_pose == null || p.pose == _pose) p]..sort(compareProgressPhotosNewestFirst);
    final groups = groupProgressPhotosByMonth(shown);
    final poses = [for (final p in ProgressPose.values) if (all.any((x) => x.pose == p)) p];

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverList.list(
              children: [
                const ProgressPhotosPrivacyNote(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => widget.onAdd(_pose),
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: Text(l10n.bodyPhotoAdd),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: all.length >= 2 ? widget.onCompare : null,
                        icon: const Icon(Icons.compare),
                        label: Text(l10n.bodyCompareTitle),
                      ),
                    ),
                  ],
                ),
                if (poses.length > 1) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(l10n.bodyPoseAll),
                            selected: _pose == null,
                            showCheckmark: false,
                            onSelected: (_) => setState(() => _pose = null),
                          ),
                        ),
                        for (final p in poses)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(progressPoseLabel(p, l10n)),
                              selected: _pose == p,
                              showCheckmark: false,
                              onSelected: (_) => setState(() => _pose = _pose == p ? null : p),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final g in groups) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(child: Text(DateFormat.yMMMM(locale).format(g.month), style: text.titleSmall)),
                    Text(
                      l10n.bodyPhotosCount(g.photos.length),
                      style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 3 / 4,
                ),
                itemCount: g.photos.length,
                itemBuilder: (context, i) {
                  final p = g.photos[i];
                  return _PhotoTile(photo: p, onTap: () => widget.onOpen(shown, shown.indexOf(p)));
                },
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final ProgressPhoto photo;
  final VoidCallback onTap;

  const _PhotoTile({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    return Semantics(
      button: true,
      image: true,
      label: progressPhotoCaption(photo, l10n, locale),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ProgressPhotoImage(photo: photo),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Row(
                children: [
                  Flexible(
                    child: ProgressPhotoBadge(
                      label: [
                        DateFormat.MMMd(locale).format(photo.takenOn),
                        if (photo.weightKg != null) SettingsService.instance.formatWeight(photo.weightKg!),
                      ].join(' · '),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 6,
              top: 6,
              child: ProgressPhotoBadge(label: progressPoseLabel(photo.pose, l10n)),
            ),
            Material(color: Colors.transparent, child: InkWell(onTap: onTap)),
          ],
        ),
      ),
    );
  }
}
