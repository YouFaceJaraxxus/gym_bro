import 'package:flutter/material.dart';

/// Gym Bro's light and dark themes.
///
/// Both derive from one seed (a deep teal: calm, "health" without the usual
/// neon-gym look) with an energetic coral tertiary for highlights such as
/// streaks, badges and secondary charts. The dark theme isn't an inversion:
/// it uses warm-neutral charcoal surfaces (never pure black, so elevation
/// still reads), lifts containers with tonal steps instead of shadows,
/// outlines cards so they separate from the background, and softens the
/// primary so it doesn't glare at night.
///
/// Screens should only read colors from `Theme.of(context).colorScheme`.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF14776A);
  static const Color _coral = Color(0xFFE8684A);

  static final ThemeData light = _build(_lightScheme());
  static final ThemeData dark = _build(_darkScheme());

  static ColorScheme _lightScheme() {
    final base = ColorScheme.fromSeed(seedColor: seed);
    final accent = ColorScheme.fromSeed(seedColor: _coral);
    return base.copyWith(
      tertiary: accent.primary,
      onTertiary: accent.onPrimary,
      tertiaryContainer: accent.primaryContainer,
      onTertiaryContainer: accent.onPrimaryContainer,
      // A touch warmer than the default neutral so pages don't feel clinical.
      surface: const Color(0xFFF8FAF8),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF2F5F3),
      surfaceContainer: const Color(0xFFECF0EE),
      surfaceContainerHigh: const Color(0xFFE6EBE8),
      surfaceContainerHighest: const Color(0xFFE0E5E2),
    );
  }

  static ColorScheme _darkScheme() {
    final base = ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark);
    final accent = ColorScheme.fromSeed(seedColor: _coral, brightness: Brightness.dark);
    return base.copyWith(
      // Softer, slightly desaturated primary: readable on charcoal without glare.
      primary: const Color(0xFF7FD6C6),
      onPrimary: const Color(0xFF00382F),
      primaryContainer: const Color(0xFF0E5148),
      onPrimaryContainer: const Color(0xFFA6F2E2),
      tertiary: accent.primary,
      onTertiary: accent.onPrimary,
      tertiaryContainer: accent.primaryContainer,
      onTertiaryContainer: accent.onPrimaryContainer,
      // Charcoal ramp with a faint green cast; each step is a visible lift.
      surface: const Color(0xFF111413),
      surfaceDim: const Color(0xFF111413),
      surfaceBright: const Color(0xFF363A39),
      surfaceContainerLowest: const Color(0xFF0C0F0E),
      surfaceContainerLow: const Color(0xFF191C1B),
      surfaceContainer: const Color(0xFF1D2120),
      surfaceContainerHigh: const Color(0xFF282B2A),
      surfaceContainerHighest: const Color(0xFF323635),
      onSurface: const Color(0xFFE1E4E2),
      onSurfaceVariant: const Color(0xFFBEC9C5),
      outline: const Color(0xFF89938F),
      outlineVariant: const Color(0xFF3F4946),
      error: const Color(0xFFFFB4AB),
    );
  }

  static ThemeData _build(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    final radius12 = BorderRadius.circular(12);
    final radius16 = BorderRadius.circular(16);
    final base = ThemeData(colorScheme: cs, useMaterial3: true);
    final text = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2),
    );

    return base.copyWith(
      extensions: [isDark ? AppColors.dark : AppColors.light],
      textTheme: text,
      scaffoldBackgroundColor: cs.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: isDark ? 0 : 2,
        shadowColor: cs.shadow.withValues(alpha: 0.2),
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius16,
          side: BorderSide(
            color: isDark ? cs.outlineVariant : cs.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius12,
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
        disabledBorder: OutlineInputBorder(borderRadius: radius12, borderSide: BorderSide.none),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: text.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: RoundedRectangleBorder(borderRadius: radius12),
          side: BorderSide(color: cs.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radius12),
          textStyle: text.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        elevation: isDark ? 0 : 3,
        shape: RoundedRectangleBorder(borderRadius: radius16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: isDark ? cs.surfaceContainer : cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        indicatorColor: cs.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? cs.onSecondaryContainer
                : cs.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: cs.outlineVariant),
        backgroundColor: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLow,
        selectedColor: cs.secondaryContainer,
        labelStyle: text.labelLarge?.copyWith(color: cs.onSurface),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: cs.secondaryContainer,
          selectedForegroundColor: cs.onSecondaryContainer,
          side: BorderSide(color: cs.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? cs.surfaceContainerLow : cs.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cs.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: cs.onInverseSurface),
        actionTextColor: cs.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: radius12),
      ),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.surfaceContainerHighest,
        circularTrackColor: Colors.transparent,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: cs.inverseSurface, borderRadius: BorderRadius.circular(8)),
        textStyle: text.bodySmall?.copyWith(color: cs.onInverseSurface),
      ),
    );
  }
}

/// Status colors Material 3 has no role for. Use through
/// `context.appColors.success` etc. so both themes stay legible; use
/// `colorScheme.error` / `errorContainer` for failures.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  static const light = AppColors(
    success: Color(0xFF1E7A3C),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD3F2DC),
    onSuccessContainer: Color(0xFF0A3D1C),
    warning: Color(0xFF8A5A00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE6B8),
    onWarningContainer: Color(0xFF3D2700),
  );

  static const dark = AppColors(
    success: Color(0xFF7DD99A),
    onSuccess: Color(0xFF00391A),
    successContainer: Color(0xFF16522B),
    onSuccessContainer: Color(0xFFC6F3D3),
    warning: Color(0xFFF2C062),
    onWarning: Color(0xFF452B00),
    warningContainer: Color(0xFF5E4200),
    onWarningContainer: Color(0xFFFFE2AD),
  );

  @override
  AppColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) =>
      AppColors(
        success: success ?? this.success,
        onSuccess: onSuccess ?? this.onSuccess,
        successContainer: successContainer ?? this.successContainer,
        onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
        warning: warning ?? this.warning,
        onWarning: onWarning ?? this.onWarning,
        warningContainer: warningContainer ?? this.warningContainer,
        onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
