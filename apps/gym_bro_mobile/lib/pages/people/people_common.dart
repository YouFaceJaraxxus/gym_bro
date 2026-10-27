import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../l10n/l10n.dart';
import '../../models/people.dart';
import '../../models/social.dart';
import '../../services/api_service.dart';
import '../../services/auth_manager.dart';

/// Shared helpers for the people screens (profiles, lists, discovery).

String peopleErrorText(Object e) => e.toString().replaceFirst('Exception: ', '');

void showPeopleSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// A small confirm dialog; resolves to true when confirmed.
Future<bool> confirmPeopleAction(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final cs = Theme.of(context).colorScheme;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel ?? ctx.l10n.commonCancel)),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive ? TextButton.styleFrom(foregroundColor: cs.error) : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// "Active now" when seen in the last 5 minutes.
bool isActiveNow(DateTime? lastActiveAt) =>
    lastActiveAt != null && DateTime.now().difference(lastActiveAt).inMinutes < 5;

/// "Active now" / "Active 2h ago", or null when unknown.
String? lastActiveText(AppLocalizations l10n, DateTime? lastActiveAt) {
  if (lastActiveAt == null) return null;
  if (isActiveNow(lastActiveAt)) return l10n.socialActiveNow;
  return l10n.socialActiveAgo(relativeTime(l10n, lastActiveAt));
}

/// "< 1 km" / "~N km".
String distanceLabel(AppLocalizations l10n, int km) =>
    km <= 0 ? l10n.peopleDistanceUnder1 : l10n.peopleDistanceKm(km);

// ── Location ─────────────────────────────────────────────────────────────────

/// Asks for location permission, reads a low-accuracy fix and sends it to the
/// server (which rounds it to ~1 km). Returns an error message, or null on
/// success.
Future<String?> shareCoarseLocation(AppLocalizations l10n) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return l10n.peopleLocationServiceOff;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return l10n.peopleLocationDenied;
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
    );
    final token = await AuthManager.instance.getValidToken();
    await ApiService().setMyLocation(token, pos.latitude, pos.longitude);
    return null;
  } catch (_) {
    return l10n.peopleLocationFailed;
  }
}

// ── Interests ────────────────────────────────────────────────────────────────

/// Suggested interests (stored as these lowercase values).
const kInterestSuggestions = [
  'powerlifting',
  'bodybuilding',
  'crossfit',
  'running',
  'yoga',
  'mobility',
  'hiit',
  'olympic lifting',
  'calisthenics',
  'cycling',
  'swimming',
  'boxing',
  'nutrition',
  'meal prep',
  'hiking',
  'climbing',
  'pilates',
  'strongman',
];

const kMaxInterests = 10;

/// Localized label for a known interest; free-text interests are shown as typed.
String interestLabel(AppLocalizations l10n, String interest) => switch (interest.trim().toLowerCase()) {
  'powerlifting' => l10n.peopleInterestPowerlifting,
  'bodybuilding' => l10n.peopleInterestBodybuilding,
  'crossfit' => l10n.peopleInterestCrossfit,
  'running' => l10n.peopleInterestRunning,
  'yoga' => l10n.peopleInterestYoga,
  'mobility' => l10n.peopleInterestMobility,
  'hiit' => l10n.peopleInterestHiit,
  'olympic lifting' => l10n.peopleInterestOlympicLifting,
  'calisthenics' => l10n.peopleInterestCalisthenics,
  'cycling' => l10n.peopleInterestCycling,
  'swimming' => l10n.peopleInterestSwimming,
  'boxing' => l10n.peopleInterestBoxing,
  'nutrition' => l10n.peopleInterestNutrition,
  'meal prep' => l10n.peopleInterestMealPrep,
  'hiking' => l10n.peopleInterestHiking,
  'climbing' => l10n.peopleInterestClimbing,
  'pilates' => l10n.peopleInterestPilates,
  'strongman' => l10n.peopleInterestStrongman,
  _ => interest,
};

// ── Suggestion reasons ───────────────────────────────────────────────────────

/// Human copy for why someone is suggested ("Goes to Ironclad Fitness").
String suggestionReasonText(AppLocalizations l10n, SuggestionReason reason) => switch (reason) {
  FollowsYouReason() => l10n.peopleReasonFollowsYou,
  MutualReason(:final count) => l10n.peopleReasonMutual(count),
  SameGymReason(:final gyms) => l10n.peopleReasonSameGym(gyms.join(', ')),
  SameTimeReason() => l10n.peopleReasonSameTime,
  SameClassReason(:final count) => l10n.peopleReasonSameClass(count),
  NearbyReason(:final km) => km <= 0 ? l10n.peopleReasonNearbyUnder1 : l10n.peopleReasonNearby(km),
  InterestsReason(:final interests) =>
    l10n.peopleReasonInterests(interests.take(2).map((i) => interestLabel(l10n, i).toLowerCase()).join(', ')),
};

IconData suggestionReasonIcon(SuggestionReason reason) => switch (reason) {
  FollowsYouReason() => Icons.person_add_alt_1_outlined,
  MutualReason() => Icons.people_outline,
  SameGymReason() => Icons.fitness_center,
  SameTimeReason() => Icons.schedule,
  SameClassReason() => Icons.event_outlined,
  NearbyReason() => Icons.near_me_outlined,
  InterestsReason() => Icons.favorite_border,
};

// ── Relationship ─────────────────────────────────────────────────────────────

extension RelationshipCopy on Relationship {
  Relationship copyWith({FollowState? following, FollowState? followedBy, FriendState? friendship, bool? blocked}) =>
      Relationship(
        following: following ?? this.following,
        followedBy: followedBy ?? this.followedBy,
        friendship: friendship ?? this.friendship,
        blocked: blocked ?? this.blocked,
      );
}

// ── Report ───────────────────────────────────────────────────────────────────

String reportReasonLabel(AppLocalizations l10n, ReportReason r) => switch (r) {
  ReportReason.spam => l10n.peopleReportReasonSpam,
  ReportReason.harassment => l10n.peopleReportReasonHarassment,
  ReportReason.inappropriate => l10n.peopleReportReasonInappropriate,
  ReportReason.impersonation => l10n.peopleReportReasonImpersonation,
  ReportReason.other => l10n.peopleReportReasonOther,
};

/// Reason picker + optional details; sends the report and shows a thank-you.
Future<void> showReportUserSheet(BuildContext context, {required String userId, required String username}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReportSheet(userId: userId, username: username),
  );
  if (sent == true && context.mounted) showPeopleSnack(context, context.l10n.peopleReportSent);
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.userId, required this.username});
  final String userId;
  final String username;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _details = TextEditingController();
  ReportReason? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final token = await AuthManager.instance.getValidToken();
      final details = _details.text.trim();
      await ApiService().report(token, userId: widget.userId, reason: reason, details: details.isEmpty ? null : details);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = peopleErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.peopleReportTitle(widget.username), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(l10n.peopleReportWhy, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) {
                  if (!_sending) setState(() => _reason = v);
                },
                child: Column(
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: r,
                        title: Text(reportReasonLabel(l10n, r)),
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _details,
                enabled: !_sending,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l10n.peopleReportDetails),
              ),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: cs.error)),
                const SizedBox(height: 8),
              ],
              FilledButton(
                onPressed: _reason == null || _sending ? null : _send,
                child: _sending
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l10n.commonLoading),
                      )
                    : Text(l10n.peopleReportSend),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Simple states ────────────────────────────────────────────────────────────

/// Centered icon + message (+ optional action) for empty / error states.
class PeopleMessageState extends StatelessWidget {
  const PeopleMessageState({super.key, required this.icon, required this.message, this.body, this.action});

  final IconData icon;
  final String message;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: text.titleMedium, textAlign: TextAlign.center),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(body!, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Error state with a Retry button.
class PeopleErrorState extends StatelessWidget {
  const PeopleErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => PeopleMessageState(
    icon: Icons.error_outline,
    message: context.l10n.commonSomethingWentWrong,
    body: message,
    action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.l10n.commonRetry)),
  );
}
