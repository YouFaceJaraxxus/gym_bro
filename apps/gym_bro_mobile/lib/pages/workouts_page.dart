import 'package:flutter/material.dart';
import '../models/training.dart';
import '../models/routine.dart';
import '../services/api_service.dart';
import '../services/auth_manager.dart';
import 'training_detail_page.dart';
import 'training_form_page.dart';
import 'routine_detail_page.dart';
import 'routine_form_page.dart';

/// Public workouts hub — tabs for Trainings, Routines, and My Library.
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
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workouts'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Trainings'),
            Tab(text: 'Routines'),
            Tab(text: 'My Library'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add),
            onSelected: (v) async {
              if (v == 'training') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TrainingFormPage()),
                );
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RoutineFormPage()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'training', child: Text('New Training')),
              PopupMenuItem(value: 'routine', child: Text('New Routine')),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _TrainingsTab(mine: false),
          _RoutinesTab(mine: false),
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
    if (_items.isEmpty) return const Center(child: Text('No trainings found'));
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
    if (_items.isEmpty) return const Center(child: Text('No routines found'));
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

// ── My Library tab (private trainings + routines) ─────────────────────────────

class _MyLibraryTab extends StatelessWidget {
  const _MyLibraryTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'My Trainings'), Tab(text: 'My Routines')],
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
                        const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                    ],
                  ),
                  if (training.description != null && training.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      training.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                  if (training.sets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${training.sets.length} sets',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                        const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          routine.scheduleLabel,
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${routine.trainings.length} training${routine.trainings.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (routine.description != null && routine.description!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      routine.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
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
          hintText: 'Search…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
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
          Text(error, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
