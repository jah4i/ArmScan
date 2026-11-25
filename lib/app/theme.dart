import 'package:material_ui/material_ui.dart';

/// ArmScan design tokens.
///
/// A calm, professional palette: deep "ink" blue for primary actions, cool
/// slate neutrals, and a single green for success states. System fonts
/// (SF Pro on iOS, Roboto on Android) keep the app fast and native-feeling.
abstract final class ArmColors {
  static const ink = Color(0xFF1F4FD8); // primary action blue
  static const inkDark = Color(0xFF8AA8FF); // primary on dark backgrounds
  static const slate900 = Color(0xFF0F172A);
  static const slate700 = Color(0xFF334155);
  static const slate500 = Color(0xFF64748B);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);
  static const success = Color(0xFF15803D);
  static const danger = Color(0xFFB91C1C);
}

abstract final class ArmSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class ArmRadius {
  static const card = 14.0;
  static const button = 12.0;
}

ThemeData buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: ArmColors.ink,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? ArmColors.inkDark : ArmColors.ink,
    surface: isDark ? const Color(0xFF0B1220) : Colors.white,
    surfaceContainerLowest: isDark ? const Color(0xFF0B1220) : ArmColors.slate50,
    surfaceContainerLow: isDark ? const Color(0xFF111A2E) : ArmColors.slate100,
    outlineVariant: isDark ? const Color(0xFF243049) : ArmColors.slate200,
    error: ArmColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    visualDensity: VisualDensity.standard,
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainerLowest,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ArmRadius.card),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArmRadius.button),
        ),
        textStyle: base.textTheme.labelLarge
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArmRadius.button),
        ),
        textStyle: base.textTheme.labelLarge
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      extendedTextStyle: base.textTheme.labelLarge
          ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ArmRadius.button),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ArmSpacing.md,
        vertical: 14,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
