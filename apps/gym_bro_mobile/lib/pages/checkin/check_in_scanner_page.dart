import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../l10n/l10n.dart';
import '../../models/check_in.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';
import 'check_in_widgets.dart';
import '../../widgets/app_bottom_sheet.dart';

/// Front-desk scanner: reads a member's check-in QR code and records the
/// visit, or checks a member in by name.
class CheckInScannerPage extends StatefulWidget {
  const CheckInScannerPage({
    super.key,
    required this.gymId,
    required this.gymName,
  });

  final String gymId;
  final String gymName;

  @override
  State<CheckInScannerPage> createState() => _CheckInScannerPageState();
}

/// What the result card shows: either an API result or an error.
class _ScanDisplay {
  final CheckInOutcome outcome;
  final CheckInResult? result;
  final String? error;
  const _ScanDisplay(this.outcome, {this.result, this.error});
}

class _CheckInScannerPageState extends State<CheckInScannerPage>
    with WidgetsBindingObserver {
  static const _resultDuration = Duration(seconds: 3);

  /// The same code held in front of the camera is ignored for this long after
  /// its result, so it doesn't loop into "already checked in".
  static const _sameCodeCooldown = Duration(seconds: 10);

  final _api = ApiService();
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _busy = false;
  _ScanDisplay? _display;
  Timer? _resumeTimer;
  String? _lastCode;
  DateTime? _lastCodeAt;
  int _sessionCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeTimer?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Permission dialogs trigger lifecycle changes before the camera is ready.
    if (!_controller.value.hasCameraPermission) return;
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(_controller.start());
      case AppLifecycleState.inactive:
        unawaited(_controller.stop());
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return;
    }
  }

  String _msg(Object e) => e.toString().replaceFirst('Exception: ', '');

  void _onDetect(BarcodeCapture capture) {
    if (_busy || _display != null) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .firstOrNull;
    if (code == null) return;
    final lastAt = _lastCodeAt;
    if (code == _lastCode &&
        lastAt != null &&
        DateTime.now().difference(lastAt) < _sameCodeCooldown) {
      return;
    }
    _lastCode = code;
    _lastCodeAt = DateTime.now();
    _submit(() async {
      final token = await AuthManager.instance.getValidToken();
      return _api.checkInWithToken(token, code, gymId: widget.gymId);
    });
  }

  Future<void> _submit(Future<CheckInResult> Function() call) async {
    setState(() => _busy = true);
    _ScanDisplay display;
    try {
      final result = await call();
      display = _ScanDisplay(result.outcome, result: result);
      if (!result.duplicate) _sessionCount++;
    } catch (e) {
      display = _ScanDisplay(CheckInOutcome.invalid, error: _msg(e));
    }
    if (!mounted) return;
    switch (display.outcome) {
      case CheckInOutcome.checkedIn:
        HapticFeedback.mediumImpact();
      case CheckInOutcome.noActiveMembership:
      case CheckInOutcome.invalid:
        HapticFeedback.heavyImpact();
      case CheckInOutcome.duplicate:
        HapticFeedback.selectionClick();
    }
    _lastCodeAt = DateTime.now();
    setState(() {
      _busy = false;
      _display = display;
    });
    _resumeTimer?.cancel();
    _resumeTimer = Timer(_resultDuration, _resume);
  }

  void _resume() {
    _resumeTimer?.cancel();
    if (mounted) setState(() => _display = null);
  }

  Future<void> _openManual() async {
    _resumeTimer?.cancel();
    final person = await showAppBottomSheet<CheckInPerson>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ManualCheckInSheet(gymId: widget.gymId),
    );
    if (person == null || !mounted) {
      if (_display != null) _resumeTimer = Timer(_resultDuration, _resume);
      return;
    }
    setState(() => _display = null);
    await _submit(() async {
      final token = await AuthManager.instance.getValidToken();
      return _api.manualCheckIn(token, widget.gymId, person.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.l10n.businessCheckInScanTitle),
            Text(widget.gymName, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (!state.isInitialized ||
                  !state.isRunning ||
                  state.torchState == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on
                    ? context.l10n.businessCheckInTorchOff
                    : context.l10n.businessCheckInTorchOn,
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
          IconButton(
            tooltip: context.l10n.businessCheckInManual,
            icon: const Icon(Icons.person_search),
            onPressed: _openManual,
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _ScannerError(
              error: error,
              onRetry: () => unawaited(_controller.start()),
              onManual: _openManual,
            ),
            overlayBuilder: (context, constraints) => const _ScanFrame(),
          ),
          if (_busy)
            Align(
              alignment: Alignment.center,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                    semanticsLabel: context.l10n.businessCheckInCheckingIn,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: _display == null
                      ? _IdleBar(
                          key: const ValueKey('idle'),
                          sessionCount: _sessionCount,
                          onManual: _openManual,
                        )
                      : _ResultCard(
                          key: ValueKey(_display),
                          display: _display!,
                          onDismiss: _resume,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: const Alignment(0, -0.3),
      child: Container(
        width: 240,
        height: 240,
        decoration: BoxDecoration(
          border: Border.all(color: cs.primaryContainer, width: 4),
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }
}

class _IdleBar extends StatelessWidget {
  const _IdleBar({
    super.key,
    required this.sessionCount,
    required this.onManual,
  });
  final int sessionCount;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(Icons.qr_code_scanner, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.l10n.businessCheckInPointCamera),
                  if (sessionCount > 0)
                    Text(
                      context.l10n.businessCheckInSessionCount(sessionCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onManual,
              child: Text(context.l10n.businessCheckInManualShort),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    super.key,
    required this.display,
    required this.onDismiss,
  });
  final _ScanDisplay display;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final palette = CheckInPalette.of(context, display.outcome);
    final tt = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final r = display.result;
    final m = r?.membership;

    final (IconData icon, String title) = switch (display.outcome) {
      CheckInOutcome.checkedIn => (
        Icons.check_circle,
        l10n.businessCheckInResultCheckedIn,
      ),
      CheckInOutcome.noActiveMembership => (
        Icons.warning_amber_rounded,
        l10n.businessCheckInResultNoMembership,
      ),
      CheckInOutcome.duplicate => (
        Icons.history,
        l10n.businessCheckInResultDuplicate,
      ),
      CheckInOutcome.invalid => (
        Icons.cancel,
        l10n.businessCheckInResultFailed,
      ),
    };

    final details = <String>[
      if (display.outcome == CheckInOutcome.duplicate && r != null)
        l10n.businessCheckInCheckedInAt(
          formatTime(context, r.checkIn.checkedInAt),
        ),
      if (m != null && m.isActive)
        l10n.businessCheckInMembershipValidUntil(
          m.typeName,
          formatYmd(context, m.toDate),
        ),
      if (m != null && !m.isActive)
        l10n.businessCheckInMembershipEnded(
          m.typeName,
          formatYmd(context, m.toDate),
        ),
      if (r != null && m == null) l10n.businessCheckInNoMembershipOnFile,
      if (display.error != null) display.error!,
    ];

    // Announced as soon as it appears; the title carries the outcome, so it
    // never relies on the card color alone.
    return Semantics(
      liveRegion: true,
      container: true,
      onTapHint: l10n.businessCheckInDismissHint,
      child: Material(
        color: palette.container,
        borderRadius: BorderRadius.circular(20),
        elevation: 3,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onDismiss,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                if (r != null)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      PersonAvatar(
                        initials: r.member.initials,
                        url: r.member.avatarUrl,
                        radius: 28,
                      ),
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: ExcludeSemantics(
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: palette.container,
                            child: Icon(
                              icon,
                              size: 20,
                              color: palette.onContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  ExcludeSemantics(
                    child: Icon(icon, size: 48, color: palette.onContainer),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: tt.labelLarge?.copyWith(
                          color: palette.onContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (r != null)
                        Text(
                          r.member.fullName,
                          style: tt.titleLarge?.copyWith(
                            color: palette.onContainer,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      for (final d in details)
                        Text(
                          d,
                          style: tt.bodyMedium?.copyWith(
                            color: palette.onContainer,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({
    required this.error,
    required this.onRetry,
    required this.onManual,
  });

  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final unsupported = error.errorCode == MobileScannerErrorCode.unsupported;
    return ColoredBox(
      color: cs.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 120),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  denied
                      ? Icons.no_photography_outlined
                      : Icons.videocam_off_outlined,
                  size: 56,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                denied
                    ? context.l10n.businessCheckInCameraDenied
                    : context.l10n.businessCheckInCameraUnavailable,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                denied
                    ? context.l10n.businessCheckInCameraDeniedMessage
                    : unsupported
                    ? context.l10n.businessCheckInCameraUnsupportedMessage
                    : context.l10n.businessCheckInCameraStartFailed(
                        error.errorCode.name,
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  if (!unsupported)
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(context.l10n.commonRetry),
                    ),
                  FilledButton.icon(
                    onPressed: onManual,
                    icon: const Icon(Icons.person_search),
                    label: Text(context.l10n.businessCheckInManual),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Manual check-in ───────────────────────────────────────────────────────────

class _ManualCheckInSheet extends StatefulWidget {
  const _ManualCheckInSheet({required this.gymId});
  final String gymId;

  @override
  State<_ManualCheckInSheet> createState() => _ManualCheckInSheetState();
}

class _ManualCheckInSheetState extends State<_ManualCheckInSheet> {
  final _api = ApiService();
  final _search = TextEditingController();
  Timer? _debounce;
  List<CheckInPerson> _results = [];
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
    setState(() {});
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final rows = await _api.searchCheckInMembers(
        token,
        widget.gymId,
        _search.text.trim(),
      );
      if (!mounted || request != _request) return;
      setState(() {
        _results = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.75,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.businessCheckInManual,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: _onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: context.l10n.businessCheckInSearchHint,
                      border: const OutlineInputBorder(),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: context.l10n.businessCheckInClearSearch,
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                _onChanged('');
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildResults(cs)),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(ColorScheme cs) {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return CheckInErrorState(message: _error!, onRetry: _load);
    }
    if (_results.isEmpty) {
      return SingleChildScrollView(
        child: CheckInEmptyState(
          icon: Icons.person_off_outlined,
          title: _search.text.trim().isEmpty
              ? context.l10n.businessCheckInNoMembers
              : context.l10n.businessCheckInNoMatches,
          message: _search.text.trim().isEmpty
              ? context.l10n.businessCheckInNoMembersMessage
              : context.l10n.businessCheckInNoMatchesMessage,
        ),
      );
    }
    return Column(
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final p = _results[i];
              return ListTile(
                leading: PersonAvatar(initials: p.initials, url: p.avatarUrl),
                title: Text(p.fullName),
                subtitle: p.email == null ? null : Text(p.email!),
                trailing: Icon(
                  Icons.login,
                  color: cs.primary,
                  semanticLabel: context.l10n.businessCheckInCheckInAction,
                ),
                onTap: () => Navigator.pop(context, p),
              );
            },
          ),
        ),
      ],
    );
  }
}
