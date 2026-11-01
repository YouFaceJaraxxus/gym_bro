import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'photo_compare_page.dart';
import 'progress_photo_widgets.dart';

/// Full-screen, swipeable progress photos (pinch to zoom). Pops with true
/// when a photo was deleted.
class ProgressPhotoViewerPage extends StatefulWidget {
  final List<ProgressPhoto> photos;
  final int initialIndex;

  /// Every photo, for "Compare" (defaults to [photos]).
  final List<ProgressPhoto>? allPhotos;

  const ProgressPhotoViewerPage({super.key, required this.photos, this.initialIndex = 0, this.allPhotos});

  @override
  State<ProgressPhotoViewerPage> createState() => _ProgressPhotoViewerPageState();
}

class _ProgressPhotoViewerPageState extends State<ProgressPhotoViewerPage> {
  late final PageController _pages = PageController(initialPage: widget.initialIndex);
  late List<ProgressPhoto> _photos = [...widget.photos];
  late int _index = widget.initialIndex;
  final _deleted = <String>{};
  bool _deleting = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final photo = _photos[_index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.bodyPhotoDeleteTitle),
        content: Text(l10n.bodyPhotoDeleteMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.commonCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final token = await AuthManager.instance.getValidToken();
      await ApiService().deleteProgressPhoto(token, photo.id);
      if (!mounted) return;
      _deleted.add(photo.id);
      if (_photos.length == 1) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _photos = [..._photos]..removeAt(_index);
        _index = _index.clamp(0, _photos.length - 1);
        _deleting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _compare() {
    final all = (widget.allPhotos ?? widget.photos).where((p) => !_deleted.contains(p.id)).toList();
    final current = _photos[_index];
    final samePose = all.where((p) => p.pose == current.pose && p.id != current.id).toList()
      ..sort(compareProgressPhotosNewestFirst);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PhotoComparePage(
          photos: all,
          before: samePose.isEmpty ? null : samePose.last,
          after: samePose.isEmpty ? null : current,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final photo = _photos[_index];
    final canCompare = (widget.allPhotos ?? widget.photos).where((p) => !_deleted.contains(p.id)).length >= 2;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _deleted.isNotEmpty);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.35),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            '${_index + 1} / ${_photos.length}',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          actions: [
            if (canCompare)
              IconButton(
                tooltip: l10n.bodyCompareTitle,
                icon: const Icon(Icons.compare, color: Colors.white),
                onPressed: _compare,
              ),
            IconButton(
              tooltip: l10n.bodyPhotoDeleteTooltip,
              icon: _deleting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: _deleting ? null : _delete,
            ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: Semantics(
                    image: true,
                    label: progressPhotoCaption(_photos[i], l10n, locale),
                    child: ProgressPhotoImage(photo: _photos[i], fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 32, 20, 20 + MediaQuery.paddingOf(context).bottom),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        progressPhotoCaption(photo, l10n, locale),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      if (photo.note != null && photo.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(photo.note!, style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
