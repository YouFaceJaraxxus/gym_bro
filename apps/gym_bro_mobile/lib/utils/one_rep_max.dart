/// Estimated one-rep max (Epley): `weight × (1 + reps / 30)`.
///
/// Matches the API's `best_e1rm`: only defined for a positive weight and at
/// least one rep; returns null otherwise. Works in any unit (kg in, kg out).
double? epleyOneRepMax(double? weight, int? reps) {
  if (weight == null || reps == null || reps < 1 || weight <= 0) return null;
  return weight * (1 + reps / 30);
}

/// Inverse of [epleyOneRepMax]: the weight expected for [reps] given a
/// one-rep max. Returns null for reps < 1 or a non-positive max.
double? epleyWeightForReps(double oneRepMax, int reps) {
  if (reps < 1 || oneRepMax <= 0) return null;
  return oneRepMax / (1 + reps / 30);
}
