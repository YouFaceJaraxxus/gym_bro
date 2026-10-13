import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/l10n.dart';
import '../../models/exercise.dart';
import '../../services/settings_service.dart';

/// Volume (kg × reps) in the user's unit, e.g. "7,758 kg" / "1.2M lb".
String formatVolume(double kg, String locale) {
  final s = SettingsService.instance;
  final v = s.toDisplayWeight(kg);
  final n = v >= 100000
      ? NumberFormat.compact(locale: locale).format(v)
      : NumberFormat.decimalPattern(locale).format(v.round());
  return '$n ${s.weightUnit.value}';
}

/// "Hamstrings, Glute Maximus" from API muscle values.
String muscleLabels(List<String> apiValues, AppLocalizations l10n) =>
    apiValues.map((v) => MuscleGroup.fromApiValue(v)?.label(l10n) ?? v).join(', ');

/// Relative day label: Today / Yesterday / Monday / Oct 6, 2025.
String relativeDay(DateTime d, AppLocalizations l10n, String locale) {
  final local = d.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(local.year, local.month, local.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return l10n.commonToday;
  if (diff == 1) return l10n.trainingProgressYesterday;
  if (diff < 7) return DateFormat.EEEE(locale).format(local);
  return DateFormat.yMMMd(locale).format(local);
}

/// Centered error with a Retry button.
class ProgressErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ProgressErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 40, color: cs.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.error),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
          ],
        ),
      ),
    );
  }
}

/// Icon + title + message empty state.
class ProgressEmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const ProgressEmptyView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: cs.primaryContainer,
            child: Icon(icon, size: 30, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            message,
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
