import 'package:flutter/material.dart';
import '../../l10n/l10n.dart';
import '../../models/progress.dart';

/// "Waist", "Body fat", … for a [BodyMetric].
String bodyMetricLabel(BodyMetric m, AppLocalizations l10n) => switch (m) {
  BodyMetric.weight => l10n.trainingMeasureBodyWeight,
  BodyMetric.bodyFat => l10n.bodyMetricBodyFat,
  BodyMetric.waist => l10n.bodyMetricWaist,
  BodyMetric.chest => l10n.bodyMetricChest,
  BodyMetric.hips => l10n.bodyMetricHips,
  BodyMetric.arm => l10n.bodyMetricArm,
  BodyMetric.thigh => l10n.bodyMetricThigh,
  BodyMetric.neck => l10n.bodyMetricNeck,
};

/// "Front", "Side", … for a [ProgressPose].
String progressPoseLabel(ProgressPose p, AppLocalizations l10n) => switch (p) {
  ProgressPose.front => l10n.bodyPoseFront,
  ProgressPose.side => l10n.bodyPoseSide,
  ProgressPose.back => l10n.bodyPoseBack,
  ProgressPose.other => l10n.bodyPoseOther,
};

IconData bodyMetricIcon(BodyMetric m) => switch (m) {
  BodyMetric.weight => Icons.monitor_weight_outlined,
  BodyMetric.bodyFat => Icons.water_drop_outlined,
  _ => Icons.straighten,
};
