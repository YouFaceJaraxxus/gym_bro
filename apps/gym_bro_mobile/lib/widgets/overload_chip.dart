import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/last_sets.dart';
import '../services/settings_service.dart';
import '../utils/overload.dart';

/// "Last: 80 kg × 8, 8, 7 · Try 82.5 kg × 8" with why underneath. Tapping it
/// (when [onApply] is set) fills the suggestion in. Nothing for no history.
class OverloadChip extends StatelessWidget {
  const OverloadChip({super.key, required this.last, required this.suggestion, this.onApply});

  final LastPerformance? last;
  final OverloadSuggestion? suggestion;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final last = this.last;
    if (last == null) return const SizedBox.shrink();
    final working = workingSets(last.sets);
    if (working.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final s = suggestion;
    final headline = [
      lastLabel(l10n, working),
      if (s != null) tryLabel(l10n, s),
    ].join(' · ');
    final reason = s == null ? null : reasonLabel(l10n, s);
    final tappable = s != null && onApply != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: tappable,
        hint: tappable ? l10n.overloadUseHint : null,
        child: Material(
          color: cs.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: tappable ? onApply : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              child: Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.trending_up, size: 18, color: cs.onSecondaryContainer)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          headline,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                        if (reason != null)
                          Text(
                            reason,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (tappable) ...[
                    const SizedBox(width: 6),
                    ExcludeSemantics(
                      child: Text(
                        l10n.overloadUse,
                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// "Last: 80 kg × 8, 8, 7", "Last: 105 × 8, 102.5 × 6 kg" or "Last: 12, 10 reps".
  static String lastLabel(AppLocalizations l10n, List<LastSet> working) {
    final settings = SettingsService.instance;
    final weights = {for (final s in working) s.weightKg ?? 0};
    if (weights.every((w) => w <= 0)) return l10n.overloadLastReps(formatRepsList(working));
    if (weights.length == 1) {
      return l10n.overloadLast('${settings.formatWeight(weights.first, decimals: 2)} × ${formatRepsList(working)}');
    }
    final unit = settings.weightUnit.value;
    String bare(double kg) {
      final w = settings.formatWeight(kg, decimals: 2);
      return w.endsWith(' $unit') ? w.substring(0, w.length - unit.length - 1) : w;
    }
    final parts = [for (final s in working) '${bare(s.weightKg ?? 0)} × ${s.reps}'];
    return l10n.overloadLast('${parts.join(', ')} $unit');
  }

  /// "Try 82.5 kg × 8" / "Try 13 reps".
  static String tryLabel(AppLocalizations l10n, OverloadSuggestion s) => s.hasWeight
      ? l10n.overloadTry(SettingsService.instance.formatWeight(s.weightKg!, decimals: 2), s.reps)
      : l10n.overloadTryReps(s.reps);

  static String reasonLabel(AppLocalizations l10n, OverloadSuggestion s) => switch (s.reason) {
        OverloadReason.addWeight => l10n.overloadReasonAddWeight(
            '${formatDisplayNumber(s.increment ?? 0)} ${SettingsService.instance.weightUnit.value}'),
        OverloadReason.addRep => l10n.overloadReasonAddRep,
        OverloadReason.bodyweightReps => l10n.overloadReasonBodyweight,
        OverloadReason.deload => l10n.overloadReasonDeload(s.daysSince),
      };
}

/// [suggestOverload] with the user's unit, for an exercise logged at [now].
OverloadSuggestion? suggestionFor(LastPerformance? last, {int? targetReps, bool isolation = false, DateTime? now}) {
  if (last == null) return null;
  return suggestOverload(
    last,
    targetReps: targetReps,
    now: now ?? DateTime.now(),
    usesPounds: SettingsService.instance.usesPounds,
    isolation: isolation,
  );
}

/// A suggested weight as typed into a field in the user's unit ("82.5").
String suggestedWeightText(OverloadSuggestion s) =>
    s.displayWeight == null ? '' : formatDisplayNumber(s.displayWeight!);
