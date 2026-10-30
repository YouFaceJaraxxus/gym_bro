import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/coaching.dart';
import '../models/training.dart';
import '../models/training_session.dart';
import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../services/settings_service.dart';
import '../widgets/share_post.dart';

class SessionDetailPage extends StatefulWidget {
  final String sessionId;

  const SessionDetailPage({super.key, required this.sessionId});

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  final _api = ApiService();
  TrainingSession? _session;
  bool _loading = true;
  String? _error;
  // exercise_id → name, resolved after load for free-session set logs.
  final Map<String, String> _exerciseNames = {};
  bool _changed = false;

  // Comments thread (owner ↔ coaches).
  List<SessionComment> _comments = [];
  bool _commentsLoading = true;
  String? _commentsError;
  final _composer = TextEditingController();
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadComments();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _refresh() => Future.wait([_load(), _loadComments()]);

  Future<void> _loadComments() async {
    setState(() {
      _commentsLoading = true;
      _commentsError = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final items = await _api.getSessionComments(token, widget.sessionId);
      if (!mounted) return;
      setState(() {
        _comments = items;
        _commentsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _commentsError = e.toString().replaceFirst('Exception: ', '');
        _commentsLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final c = await _api.addSessionComment(token, widget.sessionId, body);
      if (!mounted) return;
      _composer.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        _comments = [..._comments, c];
        _posting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      _showError(e);
    }
  }

  Future<void> _editComment(SessionComment c) async {
    final controller = TextEditingController(text: c.body);
    final l10n = context.l10n;
    final body = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingSessionCommentEditTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 1,
          maxLines: 6,
          maxLength: 4000,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (body == null || body.isEmpty || body == c.body || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      final updated = await _api.updateSessionComment(token, c.id, body);
      if (!mounted) return;
      setState(() {
        _comments = [for (final x in _comments) x.id == c.id ? updated : x];
      });
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteComment(SessionComment c) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingSessionCommentDeleteTitle),
        content: Text(l10n.trainingSessionCommentDeleteMessage),
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
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteSessionComment(token, c.id);
      if (!mounted) return;
      setState(() => _comments = _comments.where((x) => x.id != c.id).toList());
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final s = await _api.getTrainingSession(token, widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = s;
        _loading = false;
      });
      _resolveExerciseNames(token, s);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _resolveExerciseNames(String token, TrainingSession s) async {
    final ids = s.setLogs
        .map((l) => l.exerciseId)
        .whereType<String>()
        .where((id) => !_exerciseNames.containsKey(id))
        .toSet();
    if (ids.isEmpty) return;
    final results = await Future.wait(
      ids.map((id) async {
        try {
          final ex = await _api.getExercise(token, id);
          return MapEntry(id, ex.name);
        } catch (_) {
          return null;
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final e in results.whereType<MapEntry<String, String>>()) {
        _exerciseNames[e.key] = e.value;
      }
    });
  }

  void _showError(Object e) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString(), style: TextStyle(color: cs.onError)),
        backgroundColor: cs.error,
      ),
    );
  }

  Future<void> _editSet(SessionSetLog setLog, String title) async {
    final data = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditSetSheet(setLog: setLog, title: title),
    );
    if (data == null || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.updateSessionSet(token, setLog.id, data);
      _changed = true;
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deleteSet(SessionSetLog setLog) async {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingSessionSetDeleteTitle),
        content: Text(l10n.trainingSessionSetDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteSessionSet(token, setLog.id);
      _changed = true;
      await _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete() async {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.trainingSessionDeleteTitle),
        content: Text(l10n.trainingSessionDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: cs.error),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      final token = await AuthManager.instance.getValidToken();
      await _api.deleteTrainingSession(token, widget.sessionId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    if (_loading) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error ?? l10n.commonSomethingWentWrong,
                style: TextStyle(color: cs.error),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: Text(l10n.commonRetry)),
            ],
          ),
        ),
      );
    }

    final session = _session!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == session.userId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.trainingSessionDetailTitle),
          actions: [
            if (isOwner && !session.isActive) SharePostButton(target: workoutShareTarget(session)),
            if (isOwner)
              IconButton(
                tooltip: l10n.trainingSessionDeleteTooltip,
                icon: const Icon(Icons.delete_outline),
                onPressed: _delete,
              ),
          ],
        ),
        bottomNavigationBar: _buildComposer(),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _SummaryRow(
                        icon: Icons.calendar_today,
                        label: l10n.trainingSessionDate,
                        value: _formatDate(session.startedAt, locale),
                      ),
                      _SummaryRow(
                        icon: Icons.timer_outlined,
                        label: l10n.trainingSessionDuration,
                        value: session.isActive
                            ? l10n.trainingSessionInProgress
                            : session.durationLabel,
                      ),
                      if (session.trainerId != null)
                        _SummaryRow(
                          icon: Icons.person_outline,
                          label: l10n.trainingSessionTrainer,
                          value: session.trainerName ?? l10n.trainingSessionTrainer,
                        ),
                      if (session.notes != null && session.notes!.isNotEmpty)
                        _SummaryRow(
                          icon: Icons.notes,
                          label: l10n.trainingSessionNotes,
                          value: session.notes!,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (session.setLogs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.trainingSessionNoSets,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                )
              else ...[
                Text(
                  l10n.trainingSessionSetsLogged(session.setLogs.length),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                if (isOwner)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      l10n.trainingSessionTapToEdit,
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ...session.setLogs.asMap().entries.map((entry) {
                  final setLog = entry.value;
                  final exName = setLog.exerciseId != null
                      ? _exerciseNames[setLog.exerciseId]
                      : null;
                  final title = exName != null
                      ? l10n.trainingSessionSetTitleWithExercise(entry.key + 1, exName)
                      : l10n.trainingSessionSetTitle(entry.key + 1);
                  return _SetLogCard(
                    title: title,
                    setLog: setLog,
                    onEdit: isOwner ? () => _editSet(setLog, title) : null,
                    onDelete: isOwner ? () => _deleteSet(setLog) : null,
                  );
                }),
              ],
              const SizedBox(height: 24),
              ..._buildComments(session),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildComments(TrainingSession session) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final count = _commentsLoading && _comments.isEmpty ? session.commentCount : _comments.length;
    final me = AuthManager.instance.profile;
    final isSuper = me?.role == UserRole.superUser;
    final l10n = context.l10n;
    return [
      Row(
        children: [
          Icon(Icons.forum_outlined, size: 20, color: cs.primary),
          const SizedBox(width: 6),
          Text(l10n.trainingSessionComments, style: text.titleMedium),
          const SizedBox(width: 6),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  semanticsLabel: l10n.trainingSessionCommentCount(count),
                  style: text.labelSmall?.copyWith(color: cs.onSecondaryContainer)),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (_commentsLoading && _comments.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_commentsError != null && _comments.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(_commentsError!, style: TextStyle(color: cs.error), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: _loadComments, child: Text(l10n.commonRetry)),
            ],
          ),
        )
      else if (_comments.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            l10n.trainingSessionNoComments,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        )
      else
        ..._comments.map((c) {
          final mine = me != null && c.authorId == me.id;
          final isAthlete = c.authorId == session.userId;
          return _CommentTile(
            comment: c,
            label: isAthlete ? l10n.trainingSessionCommentAthlete : l10n.trainingSessionCommentCoach,
            mine: mine,
            onEdit: mine ? () => _editComment(c) : null,
            onDelete: mine || isSuper ? () => _deleteComment(c) : null,
          );
        }),
    ];
  }

  Widget _buildComposer() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 4,
          top: 6,
          bottom: 6 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l10n.trainingSessionCommentHint,
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            _posting
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    tooltip: l10n.trainingSessionSendComment,
                    icon: Icon(Icons.send, color: _composer.text.trim().isEmpty ? cs.outline : cs.primary),
                    onPressed: _composer.text.trim().isEmpty ? null : _postComment,
                  ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt, String locale) =>
      DateFormat.yMMMd(locale).add_Hm().format(dt.toLocal());
}

class _CommentTile extends StatelessWidget {
  final SessionComment comment;
  final String label;
  final bool mine;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _CommentTile({
    required this.comment,
    required this.label,
    required this.mine,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final c = comment;
    final name =
        mine ? l10n.trainingSessionCommentYou : (c.authorName ?? l10n.trainingSessionDeletedUser);
    final when = DateFormat.MMMd(locale).add_jm().format(c.createdAt.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The author's name is shown next to the avatar.
          ExcludeSemantics(
            child: CircleAvatar(
              radius: 18,
              backgroundImage: c.authorAvatarUrl != null ? NetworkImage(c.authorAvatarUrl!) : null,
              child: c.authorAvatarUrl == null
                  ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 10),
              decoration: BoxDecoration(
                color: mine ? cs.primaryContainer : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelLarge?.copyWith(
                                color: mine ? cs.onPrimaryContainer : cs.onSurface)),
                      ),
                      const SizedBox(width: 6),
                      Text('· $label',
                          style: text.labelSmall?.copyWith(
                              color: mine ? cs.onPrimaryContainer : cs.onSurfaceVariant)),
                      const Spacer(),
                      if (onEdit != null || onDelete != null)
                        PopupMenuButton<String>(
                          tooltip: l10n.trainingSessionCommentOptions,
                          iconSize: 18,
                          icon: Icon(Icons.more_vert,
                              color: mine ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                          onSelected: (v) => v == 'edit' ? onEdit?.call() : onDelete?.call(),
                          itemBuilder: (_) => [
                            if (onEdit != null)
                              PopupMenuItem(value: 'edit', child: Text(l10n.commonEdit)),
                            if (onDelete != null)
                              PopupMenuItem(value: 'delete', child: Text(l10n.commonDelete)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(c.body,
                        style: text.bodyMedium?.copyWith(
                            color: mine ? cs.onPrimaryContainer : cs.onSurface)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.isEdited ? l10n.trainingSessionCommentEdited(when) : when,
                    style: text.labelSmall?.copyWith(
                        color: (mine ? cs.onPrimaryContainer : cs.onSurfaceVariant)
                            .withValues(alpha: 0.8)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            Expanded(child: Text(value)),
          ],
        ),
      ),
    );
  }
}

class _SetLogCard extends StatelessWidget {
  final String title;
  final SessionSetLog setLog;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SetLogCard({
    required this.title,
    required this.setLog,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      tooltip: l10n.trainingSessionEditSetTooltip,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: onEdit,
                    ),
                  if (onDelete != null)
                    IconButton(
                      tooltip: l10n.trainingSessionDeleteSetTooltip,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: cs.error,
                      ),
                      onPressed: onDelete,
                    ),
                  if (onEdit == null && onDelete == null)
                    const SizedBox(height: 32),
                ],
              ),
              if (setLog.note != null && setLog.note!.isNotEmpty) ...[
                Text(
                  setLog.note!,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
              ],
              if (setLog.dropLogs.isEmpty)
                Text(
                  l10n.trainingSessionNoReps,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                )
              else
                ...setLog.dropLogs.map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_right,
                          size: 16,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(d.label(l10n), style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Edit set sheet ────────────────────────────────────────────────────────────

class _DropDraft {
  final String? trainingSetDropId;
  final int dropNumber;
  RepType repType;
  final TextEditingController reps;
  final TextEditingController weight;
  BodySide side;

  _DropDraft({
    this.trainingSetDropId,
    required this.dropNumber,
    required this.repType,
    int? repCount,
    double? weightKg,
    required this.side,
  }) : reps = TextEditingController(text: repCount?.toString() ?? ''),
       weight = TextEditingController(
         text: weightKg == null
             ? ''
             : _fmtWeight(SettingsService.instance.toDisplayWeight(weightKg)),
       );

  static String _fmtWeight(double w) {
    final r = double.parse(w.toStringAsFixed(2));
    return r == r.truncateToDouble() ? r.toInt().toString() : r.toString();
  }

  void dispose() {
    reps.dispose();
    weight.dispose();
  }
}

/// Returns the PUT body ({note, drops}) or null when cancelled.
class _EditSetSheet extends StatefulWidget {
  final SessionSetLog setLog;
  final String title;

  const _EditSetSheet({required this.setLog, required this.title});

  @override
  State<_EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends State<_EditSetSheet> {
  late final TextEditingController _note;
  final List<_DropDraft> _drops = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.setLog.note ?? '');
    for (final d in widget.setLog.dropLogs) {
      _drops.add(
        _DropDraft(
          trainingSetDropId: d.trainingSetDropId,
          dropNumber: d.dropNumber,
          repType: d.repTypeActual,
          repCount: d.repCountActual,
          weightKg: d.weightKgActual,
          side: d.side,
        ),
      );
    }
    if (_drops.isEmpty) _addDrop();
  }

  @override
  void dispose() {
    _note.dispose();
    for (final d in _drops) {
      d.dispose();
    }
    super.dispose();
  }

  void _addDrop() {
    setState(() {
      final last = _drops.isEmpty ? null : _drops.last;
      _drops.add(
        _DropDraft(
          dropNumber: _drops.length,
          repType: last?.repType ?? RepType.count,
          side: last?.side ?? BodySide.both,
        ),
      );
    });
  }

  void _removeDrop(int i) {
    setState(() {
      _drops.removeAt(i).dispose();
    });
  }

  void _submit() {
    final drops = <Map<String, dynamic>>[];
    for (var i = 0; i < _drops.length; i++) {
      final d = _drops[i];
      final repsText = d.reps.text.trim();
      final weightText = d.weight.text.trim().replaceAll(',', '.');
      final reps = int.tryParse(repsText);
      final weight = double.tryParse(weightText);
      if (d.repType == RepType.count && repsText.isNotEmpty && reps == null) {
        setState(() => _error = context.l10n.trainingSessionRepsWholeNumber);
        return;
      }
      if (weightText.isNotEmpty && weight == null) {
        setState(() => _error = context.l10n.trainingSessionWeightNumber);
        return;
      }
      drops.add({
        'training_set_drop_id': d.trainingSetDropId,
        'drop_number': i,
        'rep_type_actual': d.repType.apiValue,
        'rep_count_actual': d.repType == RepType.count ? reps : null,
        'weight_kg_actual': weight == null
            ? null
            : double.parse(SettingsService.instance.fromDisplayWeight(weight).toStringAsFixed(2)),
        'side': d.side.apiValue,
      });
    }
    Navigator.pop(context, {
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'drops': drops,
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.trainingSessionEditSetTitle(widget.title),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._drops.asMap().entries.map((entry) {
              final i = entry.key;
              final d = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 110,
                      child: DropdownButtonFormField<RepType>(
                        initialValue: d.repType,
                        isDense: true,
                        decoration: InputDecoration(
                          labelText: _drops.length > 1
                              ? l10n.trainingSessionDropNumber(i + 1)
                              : l10n.trainingSessionRepType,
                          isDense: true,
                        ),
                        items: RepType.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.label(l10n)),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => d.repType = v ?? d.repType),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (d.repType == RepType.count) ...[
                      Expanded(
                        child: TextField(
                          controller: d.reps,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: l10n.trainingRepTypeCount,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: TextField(
                        controller: d.weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: SettingsService.instance.weightUnit.value,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (_drops.length > 1)
                      IconButton(
                        tooltip: l10n.trainingSessionRemoveDrop,
                        icon: Icon(
                          Icons.close,
                          size: 18,
                          color: cs.error,
                        ),
                        onPressed: () => _removeDrop(i),
                      ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addDrop,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.trainingSessionAddDrop),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l10n.trainingSessionNote),
              maxLines: 2,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: cs.error)),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.commonCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _submit,
                    child: Text(l10n.commonSave),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
