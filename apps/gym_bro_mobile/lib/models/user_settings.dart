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

  const UserSettings({
    this.pushEnabled = true,
    this.mutedTypes = const {},
    this.weightUnit = 'kg',
    this.themeMode = 'system',
    this.locale,
    this.weeklyWorkoutTarget = 3,
    this.showOnGymBoards = true,
  });

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
      );

  Map<String, dynamic> toJson() => {
        'push_enabled': pushEnabled,
        'muted_types': mutedTypes.toList()..sort(),
        'weight_unit': weightUnit,
        'theme_mode': themeMode,
        'locale': locale,
        'weekly_workout_target': weeklyWorkoutTarget,
        'show_on_gym_boards': showOnGymBoards,
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
  }) =>
      UserSettings(
        pushEnabled: pushEnabled ?? this.pushEnabled,
        mutedTypes: mutedTypes ?? this.mutedTypes,
        weightUnit: weightUnit ?? this.weightUnit,
        themeMode: themeMode ?? this.themeMode,
        locale: clearLocale ? null : (locale ?? this.locale),
        weeklyWorkoutTarget: weeklyWorkoutTarget ?? this.weeklyWorkoutTarget,
        showOnGymBoards: showOnGymBoards ?? this.showOnGymBoards,
      );
}
