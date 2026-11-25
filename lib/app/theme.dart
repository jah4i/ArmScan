import 'package:material_ui/material_ui.dart';

/// ArmScan brand tokens, taken from the logo: gold, black and two grays.
abstract final class ArmColors {
  static const gold = Color(0xFFEDB331); // logo gold
  static const goldDeep = Color(0xFFC99317); // pressed / text on light
  static const goldSoft = Color(0xFFFFF3D6); // tinted surfaces
  static const black = Color(0xFF111111);
  static const charcoal = Color(0xFF1E1E1E);
  static const gray700 = Color(0xFF3A3A3A);
  static const gray500 = Color(0xFF808080); // logo dark gray
  static const gray300 = Color(0xFFCCCCCC); // logo light gray
  static const gray100 = Color(0xFFF0F0EE);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
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
    seedColor: ArmColors.gold,
    brightness: brightness,
  ).copyWith(
    primary: ArmColors.gold,
    onPrimary: ArmColors.black,
    primaryContainer: isDark ? const Color(0xFF3B2C08) : ArmColors.goldSoft,
    onPrimaryContainer: isDark ? ArmColors.gold : const Color(0xFF5A4103),
    secondary: isDark ? ArmColors.gray300 : ArmColors.gray700,
    onSecondary: isDark ? ArmColors.black : Colors.white,
    surface: isDark ? ArmColors.charcoal : Colors.white,
    onSurface: isDark ? const Color(0xFFF2F2F2) : ArmColors.black,
    onSurfaceVariant: isDark ? const Color(0xFFB5B5B5) : const Color(0xFF5C5C5C),
    surfaceContainerLowest: isDark ? const Color(0xFF0B0B0B) : ArmColors.gray100,
    surfaceContainerLow: isDark ? const Color(0xFF262626) : const Color(0xFFE6E6E3),
    outlineVariant: isDark ? const Color(0xFF333333) : const Color(0xFFDADAD6),
    error: ArmColors.danger,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
  );
  final label = base.textTheme.labelLarge
      ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700);

  return base.copyWith(
    // Black brand bar in both modes, like the logo's lettering.
    appBarTheme: AppBarTheme(
      backgroundColor: ArmColors.black,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
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
        backgroundColor: ArmColors.gold,
        foregroundColor: ArmColors.black,
        disabledBackgroundColor: ArmColors.gray500.withValues(alpha: 0.4),
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArmRadius.button),
        ),
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: isDark ? ArmColors.gray500 : ArmColors.gray300, width: 1.5),
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ArmRadius.button),
        ),
        textStyle: label,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: isDark ? ArmColors.gold : ArmColors.goldDeep),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: ArmColors.gold,
      foregroundColor: ArmColors.black,
      extendedTextStyle: label,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? ArmColors.black : null),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? ArmColors.gold : null),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: ArmColors.gold),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ArmRadius.button),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ArmRadius.button),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ArmRadius.button),
        borderSide: const BorderSide(color: ArmColors.gold, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: ArmSpacing.md,
        vertical: 14,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ArmColors.charcoal,
      contentTextStyle: TextStyle(color: Colors.white),
      actionTextColor: ArmColors.gold,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
  );
}
