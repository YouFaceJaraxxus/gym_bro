// User settings (GET/PUT /users/me/settings).

/// The signed-in user's preferences. The API always stores weights in kg;
/// [weightUnit] only controls display.
class UserSettings {
  final bool pushEnabled;

  /// Notification type API values (e.g. `class_reminder`) that never push.
  /// They still appear in the in-app notification list.
  final Set<String> mutedTypes;

  /// 'kg' or 'lb'.
  final String weightUnit;

  /// 'system', 'light' or 'dark'.
  final String themeMode;

  final String? locale;

  /// Workouts a week that keep a streak going in weeks with nothing planned.
  final int weeklyWorkoutTarget;

  /// Appear on the boards of gyms I'm a member of.
  final bool showOnGymBoards;

  /// API value of [FitnessGoal], or null when never chosen.
  final String? fitnessGoal;

  /// The weight chart's goal line (kg).
  final double? goalWeightKg;

  /// Daily water goal; null means [waterGoalFor] works it out from body weight.
  final int? waterGoalMl;

  /// Quick-add cup sizes (ml), 1–4 of them.
  final List<int> waterCups;

  final bool waterReminders;

  /// When the first-run flow was finished or skipped; null shows it.
  final DateTime? onboardedAt;

  const UserSettings({
    this.pushEnabled = true,
    this.mutedTypes = const {},
    this.weightUnit = 'kg',
    this.themeMode = 'system',
    this.locale,
    this.weeklyWorkoutTarget = 3,
    this.showOnGymBoards = true,
    this.fitnessGoal,
    this.goalWeightKg,
    this.waterGoalMl,
    this.waterCups = const [250, 500],
    this.waterReminders = false,
    this.onboardedAt,
  });

  /// The daily water goal: the chosen one, else ~35 ml per kg of body
  /// weight (2.5 l without a weight), rounded to 50 ml.
  int waterGoalFor(double? bodyWeightKg) {
    if (waterGoalMl != null) return waterGoalMl!;
    if (bodyWeightKg == null || bodyWeightKg <= 0) return 2500;
    return ((bodyWeightKg * 35 / 50).round() * 50).clamp(1500, 5000);
  }

  static const defaults = UserSettings();

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        pushEnabled: json['push_enabled'] as bool? ?? true,
        mutedTypes: {
          for (final t in json['muted_types'] as List? ?? const []) t.toString(),
        },
        weightUnit: json['weight_unit'] == 'lb' ? 'lb' : 'kg',
        themeMode: switch (json['theme_mode']) {
          'light' => 'light',
          'dark' => 'dark',
          _ => 'system',
        },
        locale: json['locale'] as String?,
        weeklyWorkoutTarget: int.tryParse('${json['weekly_workout_target']}') ?? 3,
        showOnGymBoards: json['show_on_gym_boards'] as bool? ?? true,
        fitnessGoal: json['fitness_goal'] as String?,
        goalWeightKg: double.tryParse('${json['goal_weight_kg']}'),
        waterGoalMl: int.tryParse('${json['water_goal_ml']}'),
        waterCups: [
          for (final c in json['water_cups'] as List? ?? const [250, 500])
            if (int.tryParse('$c') case final int ml) ml,
        ],
        waterReminders: json['water_reminders'] as bool? ?? false,
        onboardedAt: DateTime.tryParse('${json['onboarded_at']}'),
      );

  Map<String, dynamic> toJson() => {
        'push_enabled': pushEnabled,
        'muted_types': mutedTypes.toList()..sort(),
        'weight_unit': weightUnit,
        'theme_mode': themeMode,
        'locale': locale,
        'weekly_workout_target': weeklyWorkoutTarget,
        'show_on_gym_boards': showOnGymBoards,
        'fitness_goal': fitnessGoal,
        'goal_weight_kg': goalWeightKg,
        'water_goal_ml': waterGoalMl,
        'water_cups': waterCups,
        'water_reminders': waterReminders,
        'onboarded_at': onboardedAt?.toIso8601String(),
      };

  UserSettings copyWith({
    bool? pushEnabled,
    Set<String>? mutedTypes,
    String? weightUnit,
    String? themeMode,
    String? locale,
    bool clearLocale = false,
    int? weeklyWorkoutTarget,
    bool? showOnGymBoards,
    String? fitnessGoal,
    double? goalWeightKg,
    bool clearGoalWeight = false,
    int? waterGoalMl,
    bool autoWaterGoal = false,
    List<int>? waterCups,
    bool? waterReminders,
    DateTime? onboardedAt,
  }) =>
      UserSettings(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        mutedTypes: mutedTypes ?? this.mutedTypes,
        weightUnit: weightUnit ?? this.weightUnit,
        themeMode: themeMode ?? this.themeMode,
        locale: clearLocale ? null : (locale ?? this.locale),
        weeklyWorkoutTarget: weeklyWorkoutTarget ?? this.weeklyWorkoutTarget,
        showOnGymBoards: showOnGymBoards ?? this.showOnGymBoards,
        fitnessGoal: fitnessGoal ?? this.fitnessGoal,
        goalWeightKg: clearGoalWeight ? null : (goalWeightKg ?? this.goalWeightKg),
        waterGoalMl: autoWaterGoal ? null : (waterGoalMl ?? this.waterGoalMl),
        waterCups: waterCups ?? this.waterCups,
        waterReminders: waterReminders ?? this.waterReminders,
        onboardedAt: onboardedAt ?? this.onboardedAt,
      );
}

/// What the user is training for (asked during onboarding).
enum FitnessGoal {
  loseFat('lose_fat'),
  buildMuscle('build_muscle'),
  getStronger('get_stronger'),
  stayFit('stay_fit'),
  endurance('endurance');

  const FitnessGoal(this.api);
  final String api;

  static FitnessGoal? fromApi(String? v) {
    for (final g in values) {
      if (g.api == v) return g;
    }
    return null;
  }
}
