import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/draft.dart';
import '../models/social.dart' show relativeTime;
import '../services/api_service.dart';
import '../services/auth_manager.dart';

// Drafts, Instagram-style: leaving a create screen with something on it asks
// whether to save a draft (private, stored on the server); opening a create
// screen while drafts of that kind exist asks whether to start new or
// continue one.
//
// A create screen opts in with [DraftableForm] and is opened through
// [openCreateWithDrafts].

/// Opens a create screen built by [builder], first offering the user's
/// drafts of [kind] (if any) — "Start new" passes null, picking one passes
/// the loaded draft. Returns what the screen pops with.
Future<T?> openCreateWithDrafts<T>(
  BuildContext context, {
  required DraftKind kind,
  String? scopeId,
  bool fullscreenDialog = false,
  required Widget Function(Draft? draft) builder,
}) async {
  final navigator = Navigator.of(context);
  var drafts = const <DraftSummary>[];
  try {
    final token = await AuthManager.instance.getValidToken();
    drafts = await ApiService().getDrafts(token, kind, scopeId: scopeId);
  } catch (_) {
    // Offline or failing: drafts are a convenience, open a blank screen.
  }
  Draft? draft;
  if (drafts.isNotEmpty) {
    if (!context.mounted) return null;
    final choice = await showModalBottomSheet<_Choice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DraftChooserSheet(drafts: drafts),
    );
    if (choice == null || !context.mounted) return null;
    if (choice.draftId != null) {
      draft = await _loadDraft(context, choice.draftId!);
      if (draft == null) return null;
    }
  }
  return navigator.push<T>(MaterialPageRoute(fullscreenDialog: fullscreenDialog, builder: (_) => builder(draft)));
}

class _Choice {
  const _Choice(this.draftId);
  final String? draftId;
}

Future<Draft?> _loadDraft(BuildContext context, String id) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final close = _showBlockingProgress(context, l10n.draftOpening);
  try {
    final token = await AuthManager.instance.getValidToken();
    return await ApiService().getDraft(token, id);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.draftOpenFailed(_msg(e)))));
    return null;
  } finally {
    close();
  }
}

String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

/// A modal spinner with a label; returns a function that closes it.
VoidCallback _showBlockingProgress(BuildContext context, String label) {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 16),
          Expanded(child: Text(label)),
        ]),
      ),
    ),
  ).whenComplete(() => open = false);
  return () {
    if (open) navigator.pop();
    open = false;
  };
}

class _DraftChooserSheet extends StatefulWidget {
  const _DraftChooserSheet({required this.drafts});

  final List<DraftSummary> drafts;

  @override
  State<_DraftChooserSheet> createState() => _DraftChooserSheetState();
}

class _DraftChooserSheetState extends State<_DraftChooserSheet> {
  late final List<DraftSummary> _drafts = [...widget.drafts];
  final Set<String> _deleting = {};

  Future<void> _delete(DraftSummary d) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.draftDeleteTitle),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.draftDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _deleting.add(d.id));
    try {
      final token = await AuthManager.instance.getValidToken();
      await ApiService().deleteDraft(token, d.id);
      if (!mounted) return;
      setState(() {
        _drafts.removeWhere((x) => x.id == d.id);
        _deleting.remove(d.id);
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.draftDeleted)));
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting.remove(d.id));
      messenger.showSnackBar(SnackBar(content: Text(_msg(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(l10n.draftChooseTitle, style: text.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(l10n.draftChooseSubtitle, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => Navigator.pop(context, const _Choice(null)),
              icon: const Icon(Icons.add),
              label: Text(l10n.draftStartNew),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 12),
              itemCount: _drafts.length,
              itemBuilder: (context, i) {
                final d = _drafts[i];
                final subtitle = [
                  l10n.draftEdited(relativeTime(l10n, d.updatedAt)),
                  if (d.mediaCount > 0) l10n.draftMediaCount(d.mediaCount),
                ].join(' · ');
                return ListTile(
                  leading: _DraftThumb(draft: d),
                  title: Text(d.title?.isNotEmpty == true ? d.title! : l10n.draftUntitled, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: _deleting.contains(d.id) ? null : () => Navigator.pop(context, _Choice(d.id)),
                  trailing: _deleting.contains(d.id)
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(tooltip: l10n.draftDelete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(d)),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _DraftThumb extends StatelessWidget {
  const _DraftThumb({required this.draft});

  final DraftSummary draft;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Icon(draft.hasVideo ? Icons.videocam_outlined : Icons.edit_note, color: cs.onSurfaceVariant);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: cs.surfaceContainerHighest,
        child: draft.thumbnailUrl == null
            ? placeholder
            : Image.network(draft.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}

/// Draft support for a create screen. The screen supplies its state as JSON
/// ([draftData]) and restores it from [initialDraft] in initState; wrap the
/// page in [draftPopScope] and call [draftPublished] once the real thing is
/// created.
///
/// Leaving with unsaved content asks: save draft / discard / keep editing.
/// A resumed draft that wasn't changed just closes.
mixin DraftableForm<W extends StatefulWidget> on State<W> {
  DraftKind get draftKind;

  /// The draft this screen was opened from, if any.
  Draft? get initialDraft;

  /// False when editing something that already exists (no drafts then).
  bool get draftsEnabled;

  /// Whether there's anything worth saving.
  bool get hasDraftContent;

  /// The screen's state, restorable from [Draft.data].
  Map<String, dynamic> draftData();

  /// Shown in the drafts list.
  String? draftTitle();

  String? get draftScopeId => null;

  /// A public image URL for the drafts list (photos on the draft win).
  String? draftThumbnailUrl() => null;

  /// Uploads whatever media isn't uploaded yet and returns all of it.
  Future<List<DraftMedia>> draftMediaForSave() async => const [];

  /// What "changed since the draft was saved" compares; defaults to [draftData].
  Object? draftFingerprint() => draftData();

  late String? _draftId = initialDraft?.id;
  String? _baseline;
  bool _savingDraft = false;

  bool get isFromDraft => _draftId != null;

  @override
  void initState() {
    super.initState();
    // After the first frame the screen has restored the draft into its fields.
    if (initialDraft != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _baseline = jsonEncode(draftFingerprint());
      });
    }
  }

  /// For screens that restore a draft asynchronously (e.g. downloading its
  /// media): call once restored, so only later changes count as unsaved.
  void markDraftBaseline() => _baseline = jsonEncode(draftFingerprint());

  bool get _hasUnsavedDraft {
    if (!draftsEnabled) return false;
    if (_baseline != null) return jsonEncode(draftFingerprint()) != _baseline;
    return hasDraftContent;
  }

  /// Wraps the page: intercepts back to offer saving a draft. [busy] (a
  /// publish in progress) blocks leaving altogether.
  Widget draftPopScope({required Widget child, bool busy = false}) {
    return PopScope<Object?>(
      canPop: !draftsEnabled && !busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || busy || _savingDraft) return;
        if (_hasUnsavedDraft) {
          _confirmLeave();
        } else {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }

  /// A one-line "you're editing a draft" note for the top of the form.
  Widget? draftBanner(BuildContext context) {
    if (!isFromDraft || !draftsEnabled) return null;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(Icons.edit_note, color: cs.onTertiaryContainer),
        const SizedBox(width: 10),
        Expanded(child: Text(context.l10n.draftEditingBanner, style: TextStyle(color: cs.onTertiaryContainer))),
      ]),
    );
  }

  Future<void> _confirmLeave() async {
    final resumed = isFromDraft;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final l10n = ctx.l10n;
        return AlertDialog(
          title: Text(resumed ? l10n.draftUpdateTitle : l10n.draftSaveTitle),
          content: resumed ? null : Text(l10n.draftSaveBody),
          actionsOverflowAlignment: OverflowBarAlignment.end,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: Text(resumed ? l10n.draftDiscardChanges : l10n.draftDiscard)),
            TextButton(onPressed: () => Navigator.pop(ctx, 'keep'), child: Text(l10n.draftKeepEditing)),
            FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(resumed ? l10n.draftSaveChanges : l10n.draftSave)),
          ],
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'discard':
        Navigator.of(context).pop();
      case 'save':
        await _saveDraft();
    }
  }

  Future<void> _saveDraft() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    _savingDraft = true;
    final close = _showBlockingProgress(context, l10n.draftSaving);
    try {
      final media = await draftMediaForSave();
      final token = await AuthManager.instance.getValidToken();
      final title = draftTitle()?.trim();
      final saved = await ApiService().saveDraft(
        token,
        id: _draftId,
        kind: draftKind,
        scopeId: draftScopeId,
        title: title == null || title.isEmpty ? null : (title.length > 200 ? title.substring(0, 200) : title),
        thumbnailUrl: draftThumbnailUrl(),
        data: draftData(),
        media: media,
      );
      _draftId = saved.id;
      close();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l10n.draftSaved)));
      Navigator.of(context).pop();
    } catch (e) {
      close();
      messenger.showSnackBar(SnackBar(content: Text(l10n.draftSaveFailed(_msg(e)))));
    } finally {
      _savingDraft = false;
    }
  }

  /// Call after the real thing was created: the draft it came from goes.
  Future<void> draftPublished() async {
    final id = _draftId;
    if (id == null) return;
    _draftId = null;
    try {
      final token = await AuthManager.instance.getValidToken();
      await ApiService().deleteDraft(token, id);
    } catch (_) {
      // The draft stays in the list; the user can delete it there.
    }
  }
}
