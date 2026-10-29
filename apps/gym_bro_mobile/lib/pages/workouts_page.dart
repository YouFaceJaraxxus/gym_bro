import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/coaching.dart';
import '../models/draft.dart';
import '../models/training.dart';
import '../models/routine.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import '../widgets/drafts.dart';
import '../widgets/routine_assign.dart';
import 'training_detail_page.dart';
import 'training_form_page.dart';
import 'routine_detail_page.dart';
import 'routine_form_page.dart';

/// Public workouts hub — tabs for Trainings, Routines, Assigned routines and
/// My Library.
class WorkoutsPage extends StatefulWidget {
  const WorkoutsPage({super.key});

  @override
  State<WorkoutsPage> createState() => _WorkoutsPageState();
}

class _WorkoutsPageState extends State<WorkoutsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trainingWorkoutsTitle),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l10n.trainingWorkoutsTabTrainings),
            Tab(text: l10n.trainingWorkoutsTabRoutines),
            Tab(text: l10n.trainingWorkoutsTabAssigned),
            Tab(text: l10n.trainingWorkoutsTabLibrary),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: l10n.trainingWorkoutsCreate,
            icon: const Icon(Icons.add),
            onSelected: (v) async {
              if (v == 'training') {
                await openCreateWithDrafts<Training>(
                  context,
                  kind: DraftKind.training,
                  builder: (draft) => TrainingFormPage(draft: draft),
                );
              } else {
                await openCreateWithDrafts<Routine>(
                  context,
                  kind: DraftKind.routine,
                  builder: (draft) => RoutineFormPage(draft: draft),
                );
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'training', child: Text(l10n.trainingWorkoutsNewTraining)),
              PopupMenuItem(value: 'routine', child: Text(l10n.trainingWorkoutsNewRoutine)),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _TrainingsTab(mine: false),
          _RoutinesTab(mine: false),
          _AssignedTab(),
          _MyLibraryTab(),
        ],
      ),
    );
  }
}

// ── Public trainings tab ──────────────────────────────────────────────────────

class _TrainingsTab extends StatefulWidget {
  final bool mine;
  const _TrainingsTab({required this.mine});

  @override
  State<_TrainingsTab> createState() => _TrainingsTabState();
}

class _TrainingsTabState extends State<_TrainingsTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  List<Training> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      final results = await _api.getTrainings(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        mine: widget.mine,
        page: _page,
        pageSize: 20,
      );
      setState(() {
        if (reset) {
          _items = results;
        } else {
          _items.addAll(results);
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
    super.build(context);
    return Column(
      children: [
        _SearchBar(controller: _search, onSearch: () => _load(reset: true)),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) return _ErrorRetry(error: _error!, onRetry: () => _load(reset: true));
    if (_items.isEmpty) return Center(child: Text(context.l10n.trainingWorkoutsNoTrainings));
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_loading && _hasMore && n.metrics.extentAfter < 200) _load();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          final t = _items[i];
          return TrainingCard(
            training: t,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TrainingDetailPage(trainingId: t.id)),
              );
              _load(reset: true);
            },
          );
        },
      ),
    );
  }
}

// ── Public routines tab ───────────────────────────────────────────────────────

class _RoutinesTab extends StatefulWidget {
  final bool mine;
  const _RoutinesTab({required this.mine});

  @override
  State<_RoutinesTab> createState() => _RoutinesTabState();
}

class _RoutinesTabState extends State<_RoutinesTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _search = TextEditingController();
  List<Routine> _items = [];
  bool _loading = true;
  String? _error;
  int _page = 0;
  bool _hasMore = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
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
      final results = await _api.getRoutines(
        token,
        name: _search.text.trim().isEmpty ? null : _search.text.trim(),
        mine: widget.mine,
        page: _page,
        pageSize: 20,
      );
      setState(() {
        if (reset) {
          _items = results;
        } else {
          _items.addAll(results);
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
    super.build(context);
    return Column(
      children: [
        _SearchBar(controller: _search, onSearch: () => _load(reset: true)),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    if (_loading && _items.isEmpty) return const Center(child: CircularProgressIndicator());
    if (_error != null && _items.isEmpty) return _ErrorRetry(error: _error!, onRetry: () => _load(reset: true));
    if (_items.isEmpty) return Center(child: Text(context.l10n.trainingAssignNoRoutines));
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (!_loading && _hasMore && n.metrics.extentAfter < 200) _load();
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length + (_loading ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _items.length) return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
          final r = _items[i];
          return RoutineCard(
            routine: r,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoutineDetailPage(routineId: r.id)),
              );
              _load(reset: true);
            },
          );
        },
      ),
    );
  }
}

// ── Assigned routines tab (to me / by me) ─────────────────────────────────────

class _AssignedTab extends StatefulWidget {
  const _AssignedTab();

  @override
  State<_AssignedTab> createState() => _AssignedTabState();
}

class _AssignedTabState extends State<_AssignedTab> with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  List<RoutineAssignment> _toMe = [];
  List<RoutineAssignment> _byMe = [];
  bool _loading = true;
  String? _error;
  bool _showByMe = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l10n = context.l10n;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      await AuthManager.instance.ensureProfile();
      final me = AuthManager.instance.profile;
      if (me == null) throw Exception(l10n.trainingCoachNotSignedIn);
      final results = await Future.wait([
        _api.getRoutineAssignments(token, userId: me.id),
        _api.getRoutineAssignments(token, assignedById: me.id),
      ]);
      if (!mounted) return;
      setState(() {
        _toMe = results[0];
        // Self-assignments already appear under "To me".
        _byMe = results[1].where((a) => a.userId != me.id).toList();
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

  Future<void> _remove(RoutineAssignment a) async {
    if (await confirmRemoveRoutineAssignment(context, a)) _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final items = _showByMe ? _byMe : _toMe;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                  value: false, label: Text(l10n.trainingWorkoutsAssignedToMe(_toMe.length))),
              ButtonSegment(value: true, label: Text(l10n.trainingWorkoutsAssignedByMe(_byMe.length))),
            ],
            selected: {_showByMe},
            onSelectionChanged: (s) => setState(() => _showByMe = s.first),
          ),
        ),
        Expanded(
          child: Builder(builder: (context) {
            if (_loading && _toMe.isEmpty && _byMe.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null && _toMe.isEmpty && _byMe.isEmpty) {
              return _ErrorRetry(error: _error!, onRetry: _load);
            }
            return RefreshIndicator(
              onRefresh: _load,
              child: items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 64),
                        Icon(Icons.assignment_outlined, size: 48, color: cs.outline),
                        const SizedBox(height: 12),
                        Text(
                          _showByMe
                              ? l10n.trainingWorkoutsByMeEmpty
                              : l10n.trainingWorkoutsToMeEmpty,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final a = items[i];
                        final subtitle = _showByMe
                            ? (a.userName != null
                                ? l10n.trainingWorkoutsAssignedFor(a.userName!)
                                : l10n.trainingWorkoutsAssignedForMember)
                            : a.isSelfAssigned
                                ? l10n.trainingWorkoutsSelfAssigned
                                : (a.assignedByName != null
                                    ? l10n.trainingWorkoutsAssignedFrom(a.assignedByName!)
                                    : l10n.trainingWorkoutsAssignedFromCoach);
                        return RoutineAssignmentCard(
                          assignment: a,
                          subtitle: subtitle,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoutineDetailPage(routineId: a.routineId),
                              ),
                            );
                          },
                          onRemove: () => _remove(a),
                        );
                      },
                    ),
            );
          }),
        ),
      ],
    );
  }
}

// ── My Library tab (private trainings + routines) ─────────────────────────────

class _MyLibraryTab extends StatelessWidget {
  const _MyLibraryTab();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: l10n.trainingWorkoutsMyTrainings),
              Tab(text: l10n.trainingWorkoutsMyRoutines),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _TrainingsTab(mine: true),
                _RoutinesTab(mine: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card widgets ───────────────────────────────────────────────────────

class TrainingCard extends StatelessWidget {
  final Training training;
  final VoidCallback onTap;

  const TrainingCard({super.key, required this.training, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (training.thumbnailUrl.isNotEmpty)
              Image.network(
                training.thumbnailUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          training.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!training.isPublic)
                        Icon(Icons.lock_outline,
                            size: 16,
                            color: cs.onSurfaceVariant,
                            semanticLabel: l10n.trainingRoutinePrivate),
                    ],
                  ),
                  if (training.description != null && training.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      training.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                  if (training.sets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.trainingWorkoutsSetCount(training.sets.length),
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineCard extends StatelessWidget {
  final Routine routine;
  final VoidCallback onTap;

  const RoutineCard({super.key, required this.routine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (routine.thumbnailUrl.isNotEmpty)
              Image.network(
                routine.thumbnailUrl,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stack) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          routine.name,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (!routine.isPublic)
                        Icon(Icons.lock_outline,
                            size: 16,
                            color: cs.onSurfaceVariant,
                            semanticLabel: l10n.trainingRoutinePrivate),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          routine.scheduleLabel(l10n),
                          style: TextStyle(fontSize: 11, color: cs.onSecondaryContainer),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.trainingRoutineTrainingCount(routine.trainings.length),
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  if (routine.description != null && routine.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      routine.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;

  const _SearchBar({required this.controller, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: context.l10n.commonSearch,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  tooltip: context.l10n.trainingWorkoutsClearSearch,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onSearch();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
        ),
        onSubmitted: (_) => onSearch(),
      ),
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorRetry({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }
}
