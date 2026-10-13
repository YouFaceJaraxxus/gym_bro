import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/l10n.dart';
import '../models/training_session.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../theme.dart';
import 'session_detail_page.dart';
import 'progress/progress_page.dart';
import 'session_log_page.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key, this.asTrainerId});

  /// When set, shows sessions this trainer is running for others ("Classes")
  /// instead of the caller's own sessions ("Schedule").
  final String? asTrainerId;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _api = ApiService();
  List<TrainingSession> _sessions = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;

  bool get _isTrainerView => widget.asTrainerId != null;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await _api.getTrainingSessions(
        token,
        trainerId: widget.asTrainerId,
        page: _page,
        pageSize: 20,
      );
      setState(() {
        if (reset) {
          _sessions = results;
        } else {
          _sessions.addAll(results);
        }
        _hasMore = results.length == 20;
        _page++;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isTrainerView ? l10n.trainingSessionsClassesTitle : l10n.trainingSessionsTitle),
        actions: [
          if (!_isTrainerView)
            IconButton(
              tooltip: l10n.trainingSessionsMyProgress,
              icon: const Icon(Icons.insights_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProgressPage()),
              ),
            ),
        ],
      ),
      floatingActionButton: _isTrainerView
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SessionLogPage()),
                );
                if (result == true) _load(reset: true);
              },
              icon: const Icon(Icons.play_arrow),
              label: Text(l10n.trainingSessionsNew),
            ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    if (_loading && _sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: TextStyle(color: cs.error)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(reset: true), child: Text(l10n.commonRetry)),
          ],
        ),
      );
    }
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _isTrainerView ? l10n.trainingSessionsNoClasses : l10n.trainingSessionsEmpty,
              style: TextStyle(fontSize: 18, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              _isTrainerView
                  ? l10n.trainingSessionsNoClassesHint
                  : l10n.trainingSessionsEmptyHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (!_loading && _hasMore && n.metrics.extentAfter < 200) {
            _load();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _sessions.length + (_loading ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == _sessions.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final s = _sessions[i];
            return _SessionCard(
              session: s,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id)),
                );
                _load(reset: true);
              },
            );
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final TrainingSession session;
  final VoidCallback onTap;

  const _SessionCard({required this.session, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final appColors = context.appColors;
    final l10n = context.l10n;
    final dateStr = _formatDate(session.startedAt.toLocal(), l10n, Localizations.localeOf(context).toString());
    final duration = session.durationLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: session.isActive ? appColors.successContainer : cs.primaryContainer,
          child: Icon(
            session.isActive ? Icons.radio_button_checked : Icons.fitness_center,
            color: session.isActive ? appColors.onSuccessContainer : cs.onPrimaryContainer,
            size: 20,
          ),
        ),
        title: Text(
          session.trainingId != null ? l10n.trainingSessionPlanned : l10n.trainingSessionFree,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr, style: const TextStyle(fontSize: 12)),
            if (session.isActive)
              Text(l10n.trainingSessionInProgress,
                  style: TextStyle(color: appColors.success, fontSize: 12))
            else
              Text(duration,
                  semanticsLabel: l10n.trainingSessionDurationSemantics(duration),
                  style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: session.commentCount > 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum_outlined, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${session.commentCount}',
                      semanticsLabel: l10n.trainingSessionCommentCount(session.commentCount),
                      style: TextStyle(color: cs.onSurfaceVariant)),
                  const Icon(Icons.chevron_right),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime dt, AppLocalizations l10n, String locale) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    final time = DateFormat.Hm(locale).format(dt);
    if (diff.inDays == 0) return l10n.trainingSessionTodayAt(time);
    if (diff.inDays == 1) return l10n.trainingSessionYesterdayAt(time);
    return '${DateFormat.yMMMd(locale).format(dt)} $time';
  }
}
