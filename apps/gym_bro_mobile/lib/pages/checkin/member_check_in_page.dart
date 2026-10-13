import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../l10n/l10n.dart';
import '../../models/check_in.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'check_in_widgets.dart';

/// The member's check-in QR code for one of their gyms, refreshed before it
/// expires, plus their visit history.
class MemberCheckInPage extends StatefulWidget {
  const MemberCheckInPage({super.key});

  @override
  State<MemberCheckInPage> createState() => _MemberCheckInPageState();
}

class _MemberCheckInPageState extends State<MemberCheckInPage>
    with WidgetsBindingObserver {
  static const _historyPageSize = 30;

  final _api = ApiService();

  // Gyms
  List<CheckInGym> _gyms = [];
  bool _staffOnly = false;
  CheckInGym? _gym;
  bool _loading = true;
  String? _error;

  // QR token
  CheckInToken? _token;
  bool _tokenLoading = false;
  String? _tokenError;
  bool _notConfigured = false;
  Timer? _ticker;
  int _tokenRequest = 0;

  // History
  List<CheckIn> _history = [];
  MyCheckInStats? _stats;
  bool _historyLoading = false;
  bool _historyHasMore = false;
  bool _loadingMore = false;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background: the code may have expired meanwhile.
    if (state == AppLifecycleState.resumed) _tick();
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _tick() {
    if (!mounted) return;
    final t = _token;
    if (t != null &&
        t.shouldRefresh() &&
        !_tokenLoading &&
        _tokenError == null) {
      _fetchToken();
    }
    // Repaint the countdown.
    if (t != null) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final all = await _api.getCheckInGyms(token);
      final memberGyms = all.where((g) => g.isMember).toList();
      // Staff with no memberships can still preview the flow at their gyms.
      final gyms = memberGyms.isNotEmpty ? memberGyms : all;
      if (!mounted) return;
      setState(() {
        _gyms = gyms;
        _staffOnly = memberGyms.isEmpty && all.isNotEmpty;
        _gym =
            gyms.where((g) => g.gymId == _gym?.gymId).firstOrNull ??
            gyms.firstOrNull;
        _loading = false;
      });
      if (_gym != null) _fetchToken();
      _loadHistory();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _msg(e);
          _loading = false;
        });
      }
    }
  }

  Future<void> _fetchToken() async {
    final gym = _gym;
    if (gym == null) return;
    final request = ++_tokenRequest;
    setState(() {
      _tokenLoading = true;
      _tokenError = null;
    });
    try {
      final auth = await AuthManager.instance.getValidToken();
      final t = await _api.getCheckInToken(auth, gym.gymId);
      if (!mounted || request != _tokenRequest) return;
      setState(() {
        _token = t;
        _tokenLoading = false;
        _notConfigured = false;
      });
      // A staff scan may have happened since the last code; keep history fresh.
      if (_history.isNotEmpty || _stats != null) _loadHistory(silent: true);
    } catch (e) {
      if (!mounted || request != _tokenRequest) return;
      setState(() {
        _token = null;
        _tokenLoading = false;
        _notConfigured = e is CheckInException && e.isNotConfigured;
        _tokenError = _msg(e);
      });
    }
  }

  void _selectGym(CheckInGym gym) {
    if (gym.gymId == _gym?.gymId) return;
    setState(() {
      _gym = gym;
      _token = null;
    });
    _fetchToken();
  }

  Future<void> _loadHistory({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _historyLoading = _history.isEmpty;
        _historyError = null;
      });
    }
    try {
      final token = await AuthManager.instance.getValidToken();
      final results = await Future.wait([
        _api.getMyCheckIns(token, pageSize: _historyPageSize),
        _api.getMyCheckInStats(token),
      ]);
      if (!mounted) return;
      final rows = results[0] as List<CheckIn>;
      setState(() {
        _history = rows;
        _stats = results[1] as MyCheckInStats;
        _historyHasMore = rows.length == _historyPageSize;
        _historyLoading = false;
        _historyError = null;
      });
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _historyError = _msg(e);
          _historyLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.getMyCheckIns(
        token,
        page: _history.length ~/ _historyPageSize,
        pageSize: _historyPageSize,
      );
      if (!mounted) return;
      final known = _history.map((c) => c.id).toSet();
      setState(() {
        _history = [..._history, ...rows.where((c) => !known.contains(c.id))];
        _historyHasMore = rows.length == _historyPageSize;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_msg(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([if (_gym != null) _fetchToken(), _loadHistory()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.businessCheckInTitle)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return CheckInErrorState(message: _error!, onRetry: _load);
    }
    if (_gyms.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            CheckInEmptyState(
              icon: Icons.fitness_center,
              title: context.l10n.businessCheckInNoGymTitle,
              message: context.l10n.businessCheckInNoGymMessage,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_gyms.length > 1) _buildGymSelector(),
          if (_staffOnly) _buildStaffNotice(),
          _buildQrCard(),
          const SizedBox(height: 20),
          _buildStats(),
          const SizedBox(height: 20),
          Text(
            context.l10n.businessCheckInRecentVisits,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ..._buildHistory(),
        ],
      ),
    );
  }

  Widget _buildGymSelector() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _gyms.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final g = _gyms[i];
          return ChoiceChip(
            label: Text(g.name),
            avatar: const Icon(Icons.fitness_center, size: 16),
            selected: g.gymId == _gym?.gymId,
            onSelected: (_) => _selectGym(g),
          );
        },
      ),
    );
  }

  Widget _buildStaffNotice() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.info_outline,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              context.l10n.businessCheckInStaffNotice,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = _token;
    final remaining = t?.remaining() ?? Duration.zero;
    final progress = t == null || t.ttlSeconds == 0
        ? 0.0
        : (remaining.inMilliseconds / (t.ttlSeconds * 1000)).clamp(0.0, 1.0);
    final mm = remaining.inMinutes;
    final ss = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    Widget content;
    if (_tokenError != null && t == null) {
      content = SizedBox(
        height: 260,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  _notConfigured ? Icons.qr_code_2 : Icons.error_outline,
                  size: 48,
                  color: _notConfigured ? cs.outline : cs.error,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _notConfigured
                    ? context.l10n.businessCheckInQrNotConfigured
                    : _tokenError!,
                textAlign: TextAlign.center,
              ),
              if (!_notConfigured) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _fetchToken,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.commonRetry),
                ),
              ],
            ],
          ),
        ),
      );
    } else if (t == null) {
      content = const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      content = Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Container(
              key: ValueKey(t.token),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                // Scanners need dark modules on a light background, whatever
                // the app theme, so the code itself is always black on white.
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: t.token,
                size: 240,
                padding: EdgeInsets.zero,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
                semanticsLabel: context.l10n.businessCheckInQrSemantics(
                  t.gymName,
                ),
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF000000),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF000000),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: progress, minHeight: 6),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_tokenLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              Text(
                _tokenLoading
                    ? context.l10n.businessCheckInRefreshingCode
                    : _tokenError != null
                    ? context.l10n.businessCheckInRefreshFailed(_tokenError!)
                    : context.l10n.businessCheckInNewCodeIn('$mm:$ss'),
                style: tt.bodySmall?.copyWith(
                  color: _tokenError != null ? cs.error : cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (_tokenError != null)
                IconButton(
                  tooltip: context.l10n.businessCheckInRefreshCode,
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _fetchToken,
                ),
            ],
          ),
        ],
      );
    }

    return Card(
      elevation: 0,
      color: cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          children: [
            Text(
              _gym?.name ?? '',
              style: tt.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.businessCheckInShowAtDesk,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    final s = _stats;
    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.calendar_month,
            label: context.l10n.businessCheckInVisitsThisMonth,
            value: s == null ? '–' : '${s.thisMonth}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: Icons.date_range,
            label: context.l10n.businessCheckInThisWeek,
            value: s == null ? '–' : '${s.thisWeek}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            icon: Icons.emoji_events_outlined,
            label: context.l10n.businessCheckInAllTime,
            value: s == null ? '–' : '${s.total}',
          ),
        ),
      ],
    );
  }

  List<Widget> _buildHistory() {
    final cs = Theme.of(context).colorScheme;
    if (_historyLoading) {
      return const [
        Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_historyError != null) {
      return [
        CheckInErrorState(message: _historyError!, onRetry: _loadHistory),
      ];
    }
    if (_history.isEmpty) {
      return [
        CheckInEmptyState(
          icon: Icons.directions_walk,
          title: context.l10n.businessCheckInNoVisitsTitle,
          message: context.l10n.businessCheckInNoVisitsMessage,
        ),
      ];
    }
    return [
      Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: cs.surfaceContainerLow,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < _history.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 72),
              MergeSemantics(
                child: ListTile(
                  leading: ExcludeSemantics(
                    child: CircleAvatar(
                      backgroundColor: cs.secondaryContainer,
                      child: Icon(
                        _history[i].isManual
                            ? Icons.how_to_reg
                            : Icons.qr_code_scanner,
                        color: cs.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    _history[i].gymName ??
                        context.l10n.businessCheckInGymFallback,
                  ),
                  subtitle: Text(
                    '${formatDay(context, _history[i].checkedInAt)} · ${formatTime(context, _history[i].checkedInAt)}'
                    '${_history[i].isManual ? ' · ${context.l10n.businessCheckInByStaff}' : ''}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      if (_historyHasMore)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Center(
            child: _loadingMore
                ? const CircularProgressIndicator()
                : OutlinedButton(
                    onPressed: _loadMoreHistory,
                    child: Text(context.l10n.businessCheckInShowMore),
                  ),
          ),
        ),
    ];
  }
}
