import 'package:flutter/material.dart';
import '../models/training_session.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';

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
      final s = await _api.getTrainingSession(token, widget.sessionId);
      setState(() {
        _session = s;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: const Text('This log entry will be permanently removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _session == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ]),
        ),
      );
    }

    final session = _session!;
    final profile = AuthManager.instance.profile;
    final isOwner = profile != null && profile.id == session.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Detail'),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _SummaryRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: _formatDate(session.startedAt),
                    ),
                    _SummaryRow(
                      icon: Icons.timer_outlined,
                      label: 'Duration',
                      value: session.isActive ? 'In progress' : session.durationLabel,
                    ),
                    if (session.trainerId != null)
                      _SummaryRow(
                        icon: Icons.person_outline,
                        label: 'Trainer',
                        value: session.trainerId!,
                      ),
                    if (session.notes != null && session.notes!.isNotEmpty)
                      _SummaryRow(
                        icon: Icons.notes,
                        label: 'Notes',
                        value: session.notes!,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (session.setLogs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No sets logged', style: TextStyle(color: Colors.grey)),
                ),
              )
            else ...[
              Text(
                '${session.setLogs.length} Set${session.setLogs.length == 1 ? '' : 's'} Logged',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ...session.setLogs.asMap().entries.map((entry) =>
                  _SetLogCard(index: entry.key, setLog: entry.value)),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 10),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _SetLogCard extends StatelessWidget {
  final int index;
  final SessionSetLog setLog;

  const _SetLogCard({required this.index, required this.setLog});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (setLog.note != null && setLog.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(setLog.note!, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
            if (setLog.dropLogs.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...setLog.dropLogs.map((d) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.arrow_right, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(d.label, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
