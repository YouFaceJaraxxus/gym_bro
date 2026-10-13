import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/gym_class.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'class_detail_page.dart';
import 'class_form_page.dart';
import 'schedule_widgets.dart';

/// Classes the caller teaches (Upcoming / Past) with a button to create one.
class TrainerClassesPage extends StatefulWidget {
  const TrainerClassesPage({super.key});

  @override
  State<TrainerClassesPage> createState() => _TrainerClassesPageState();
}

class _TrainerClassesPageState extends State<TrainerClassesPage> {
  static const _pastDays = 90;
  static const _futureDays = 120;

  final _api = ApiService();
  List<GymClass> _classes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = AuthManager.instance.profile?.id;
    final notSignedIn = context.l10n.trainingClassNotSignedIn;
    setState(() {
      _loading = _classes.isEmpty;
      _error = null;
    });
    try {
      if (me == null) throw Exception(notSignedIn);
      final token = await AuthManager.instance.getValidToken();
      final now = DateTime.now();
      final classes = await _api.getClasses(
        token,
        trainerId: me,
        from: now.subtract(const Duration(days: _pastDays)),
        to: now.add(const Duration(days: _futureDays)),
      );
      if (!mounted) return;
      setState(() {
        _classes = classes;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ClassFormPage()),
    );
    if (saved == true && mounted) _load();
  }

  Future<void> _open(GymClass c) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClassDetailPage(classId: c.id)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = _classes.where((c) => !c.isPast).toList();
    final past = _classes.where((c) => c.isPast).toList().reversed.toList();
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.trainingClassMyClasses),
          bottom: TabBar(
            tabs: [
              Tab(
                  text: upcoming.isEmpty
                      ? l10n.trainingClassUpcoming
                      : l10n.trainingClassUpcomingCount(upcoming.length)),
              Tab(text: l10n.trainingClassPast),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _create,
          icon: const Icon(Icons.add),
          label: Text(l10n.trainingClassNew),
        ),
        body: TabBarView(
          children: [
            RefreshIndicator(
              onRefresh: _load,
              child: _buildList(upcoming, upcoming: true),
            ),
            RefreshIndicator(
              onRefresh: _load,
              child: _buildList(past, upcoming: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<GymClass> classes, {required bool upcoming}) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ScheduleError(message: _error!, onRetry: _load);
    final l10n = context.l10n;
    if (classes.isEmpty) {
      return upcoming
          ? ScheduleEmpty(
              icon: Icons.event_note,
              title: l10n.trainingClassNoUpcoming,
              message: l10n.trainingClassNoUpcomingMessage,
              action: FilledButton.tonalIcon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text(l10n.trainingClassCreateOne),
              ),
            )
          : ScheduleEmpty(
              icon: Icons.history,
              title: l10n.trainingClassNoPast,
              message: l10n.trainingClassNoPastMessage(_pastDays),
            );
    }
    final multipleGyms = _classes.map((c) => c.gymId).toSet().length > 1;
    final groups = groupByDay(classes, (c) => c.startsAt);
    final children = <Widget>[];
    for (final entry in groups.entries) {
      children.add(DayHeader(
        entry.key,
        trailing: l10n.trainingClassCount(entry.value.length),
      ));
      for (final c in entry.value) {
        children.add(ClassCard(
          key: ValueKey(c.id),
          gymClass: c,
          showGym: multipleGyms,
          onTap: () => _open(c),
        ));
      }
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: children,
    );
  }
}
