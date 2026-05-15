import 'package:flutter/material.dart';
import '../models/training_session.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'session_detail_page.dart';
import 'session_log_page.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({super.key});

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
    return Scaffold(
      appBar: AppBar(title: const Text('Sessions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SessionLogPage()),
          );
          if (result == true) _load(reset: true);
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('New Session'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _sessions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => _load(reset: true), child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_sessions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No sessions yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
            SizedBox(height: 8),
            Text('Tap + to start your first workout', style: TextStyle(color: Colors.grey)),
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
    final dateStr = _formatDate(session.startedAt);
    final duration = session.durationLabel;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: session.isActive
              ? Colors.green.shade100
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            session.isActive ? Icons.radio_button_checked : Icons.fitness_center,
            color: session.isActive ? Colors.green : null,
            size: 20,
          ),
        ),
        title: Text(
          session.trainingId != null ? 'Training Session' : 'Free Session',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr, style: const TextStyle(fontSize: 12)),
            if (session.isActive)
              const Text('In progress…', style: TextStyle(color: Colors.green, fontSize: 12))
            else
              Text(duration, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today ${_time(dt)}';
    if (diff.inDays == 1) return 'Yesterday ${_time(dt)}';
    return '${dt.day}/${dt.month}/${dt.year} ${_time(dt)}';
  }

  String _time(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
