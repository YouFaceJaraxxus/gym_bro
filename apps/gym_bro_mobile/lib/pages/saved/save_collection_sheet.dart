import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/social_widgets.dart';

/// "Save to collection" (Instagram's long press on the bookmark): "All
/// posts" (saved or not) and each of my collections with a check when it
/// holds [post], plus "New collection". Every tap is applied right away;
/// [onSavedChanged] reports the post's saved state whenever it changes.
Future<void> showSaveToCollectionSheet(
  BuildContext context, {
  required Post post,
  ValueChanged<bool>? onSavedChanged,
}) => showAppBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => _SaveToCollectionSheet(post: post, onSavedChanged: onSavedChanged),
);

/// Asks for a collection name (new or [initial] to rename); null when
/// cancelled.
Future<String?> promptCollectionName(BuildContext context, {required String title, String initial = ''}) =>
    showDialog<String>(context: context, builder: (_) => _CollectionNameDialog(title: title, initial: initial));

class _SaveToCollectionSheet extends StatefulWidget {
  const _SaveToCollectionSheet({required this.post, this.onSavedChanged});

  final Post post;
  final ValueChanged<bool>? onSavedChanged;

  @override
  State<_SaveToCollectionSheet> createState() => _SaveToCollectionSheetState();
}

class _SaveToCollectionSheetState extends State<_SaveToCollectionSheet> {
  final _api = ApiService();
  SavedOverview? _overview;
  late bool _saved = widget.post.savedByMe;
  String? _error;

  /// Collection ids (or '' for "All posts") with a request in flight.
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final token = await AuthManager.instance.getValidToken();
      final overview = await _api.getSaveCollections(token, postId: widget.post.id);
      if (!mounted) return;
      setState(() => _overview = overview);
      _setSaved(overview.postSaved ?? _saved);
    } catch (e) {
      if (mounted) setState(() => _error = _msg(e));
    }
  }

  void _setSaved(bool saved) {
    if (saved == _saved) return;
    if (mounted) setState(() => _saved = saved);
    widget.onSavedChanged?.call(saved);
  }

  void _snack(String text) => ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  void _patch(String id, bool contains) {
    final o = _overview;
    if (o == null) return;
    setState(() {
      _overview = SavedOverview(
        saved: o.saved,
        postSaved: o.postSaved,
        collections: [
          for (final c in o.collections)
            c.id == id
                ? c.copyWith(containsPost: contains, postCount: (c.postCount + (contains ? 1 : -1)).clamp(0, 1 << 30))
                : c,
        ],
      );
    });
  }

  Future<void> _toggleAll() async {
    if (_busy.contains('')) return;
    final l10n = context.l10n;
    final was = _saved;
    setState(() => _busy.add(''));
    _setSaved(!was);
    try {
      final token = await AuthManager.instance.getValidToken();
      if (was) {
        await _api.unsavePost(token, widget.post.id);
        // Unsaving takes it out of every collection too.
        final o = _overview;
        if (o != null && mounted) {
          for (final c in o.collections.where((c) => c.containsPost == true)) {
            _patch(c.id, false);
          }
        }
        _snack(l10n.postsRemovedFromSaved);
      } else {
        await _api.savePost(token, widget.post.id);
        _snack(l10n.postsSavedToast);
      }
    } catch (e) {
      _setSaved(was);
      _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy.remove(''));
    }
  }

  Future<void> _toggle(SaveCollection c) async {
    if (_busy.contains(c.id)) return;
    final l10n = context.l10n;
    final had = c.containsPost == true;
    setState(() => _busy.add(c.id));
    _patch(c.id, !had);
    try {
      final token = await AuthManager.instance.getValidToken();
      if (had) {
        await _api.removeFromSaveCollection(token, c.id, widget.post.id);
        _snack(l10n.postsRemovedFrom(c.name));
      } else {
        await _api.addToSaveCollection(token, c.id, widget.post.id);
        _setSaved(true);
        _snack(l10n.postsSavedTo(c.name));
      }
    } catch (e) {
      _patch(c.id, had);
      _snack(_msg(e));
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  Future<void> _create() async {
    final l10n = context.l10n;
    final name = await promptCollectionName(context, title: l10n.postsNewCollection);
    if (name == null || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final created = await _api.createSaveCollection(token, name, postIds: [widget.post.id]);
      if (!mounted) return;
      final o = _overview ?? const SavedOverview();
      setState(() {
        _overview = SavedOverview(
          saved: o.saved,
          postSaved: true,
          collections: [created.copyWith(containsPost: true), ...o.collections],
        );
      });
      _setSaved(true);
      _snack(l10n.postsSavedTo(created.name));
    } catch (e) {
      _snack(_msg(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final o = _overview;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(children: [
            Expanded(child: Text(l10n.postsSaveToCollection, style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(onPressed: _create, icon: const Icon(Icons.add), label: Text(l10n.postsNewCollection)),
          ]),
        ),
        const Divider(height: 1),
        if (o == null && _error == null)
          const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        else if (o == null)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
              const SizedBox(height: 8),
              TextButton(onPressed: _load, child: Text(l10n.commonRetry)),
            ]),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _row(
                  context,
                  cover: o.saved.covers.isEmpty ? null : o.saved.covers.first,
                  title: l10n.postsAllPosts,
                  checked: _saved,
                  busy: _busy.contains(''),
                  onTap: _toggleAll,
                  icon: Icons.bookmark_border,
                ),
                for (final c in o.collections)
                  _row(
                    context,
                    cover: c.covers.isEmpty ? null : c.covers.first,
                    title: c.name,
                    subtitle: l10n.postsPostCount(c.postCount),
                    checked: c.containsPost == true,
                    busy: _busy.contains(c.id),
                    onTap: () => _toggle(c),
                    icon: Icons.collections_bookmark_outlined,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ]),
    );
  }

  Widget _row(
    BuildContext context, {
    required SaveCover? cover,
    required String title,
    String? subtitle,
    required bool checked,
    required bool busy,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: busy ? null : onTap,
      leading: SizedBox(width: 48, height: 48, child: CoverThumb(cover: cover, icon: icon, radius: 8)),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(
              checked ? Icons.check_circle : Icons.radio_button_unchecked,
              color: checked ? cs.primary : cs.outline,
            ),
      selected: checked,
    );
  }
}

/// A saved post's cover (photo, or a dark tile with ▶ for a video), or
/// [icon] on a tinted tile when there's none.
class CoverThumb extends StatelessWidget {
  const CoverThumb({super.key, required this.cover, this.icon = Icons.bookmark_border, this.radius = 0});

  final SaveCover? cover;
  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = cover;
    final Widget child;
    if (c == null || c.url == null) {
      child = ColoredBox(color: cs.surfaceContainerHighest, child: Center(child: Icon(icon, color: cs.onSurfaceVariant)));
    } else if (c.isVideo) {
      child = const ColoredBox(
        color: Color(0xFF1C1C1E),
        child: Center(child: Icon(Icons.play_arrow_rounded, color: Colors.white70)),
      );
    } else {
      child = MediaImage(url: c.url!);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class _CollectionNameDialog extends StatefulWidget {
  const _CollectionNameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_CollectionNameDialog> createState() => _CollectionNameDialogState();
}

class _CollectionNameDialogState extends State<_CollectionNameDialog> {
  late final _name = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _name,
        autofocus: true,
        maxLength: kCollectionNameMaxLength,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l10n.postsCollectionName),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
        FilledButton(
          onPressed: _name.text.trim().isEmpty ? null : _submit,
          child: Text(widget.initial.isEmpty ? l10n.postsCreate : l10n.commonSave),
        ),
      ],
    );
  }
}
