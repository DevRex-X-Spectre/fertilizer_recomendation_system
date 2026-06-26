// lib/core/theme.dart
// Material 3 agricultural theme. Tuned for legibility and a distinctive
// (non-default) feel: deep forest green primary + warm terracotta accent,
// warm cream surface, refined card geometry.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF1B5E20); // deep forest green
  static const Color primaryContainer = Color(0xFFC8E6C9);
  static const Color accent        = Color(0xFFC2410C); // terracotta
  static const Color accentContainer = Color(0xFFFFE4D6);
  static const Color surface       = Color(0xFFFBF8F3); // warm cream
  static const Color surfaceTint   = Color(0xFFFFFFFF);
  static const Color outline       = Color(0xFFE5E0D5);
  static const Color outlineVariant = Color(0xFFEEE9DC);
  static const Color error         = Color(0xFFB91C1C);

  // Status colors for nutrient readings.
  static const Color statusDeficient = Color(0xFFDC2626);
  static const Color statusLow       = Color(0xFFF59E0B);
  static const Color statusAdequate  = Color(0xFF15803D);
  static const Color statusExcess    = Color(0xFF2563EB);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: const Color(0xFF0A2E0F),
      secondary: accent,
      onSecondary: Colors.white,
      secondaryContainer: accentContainer,
      onSecondaryContainer: const Color(0xFF4A1F0E),
      surface: surface,
      onSurface: const Color(0xFF1A1F18),
      surfaceContainerHighest: const Color(0xFFF1ECE0),
      outline: outline,
      outlineVariant: const Color(0xFFEEE9DC),
      error: error,
    );

    final baseText = GoogleFonts.notoSansTextTheme();

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surface,
      textTheme: baseText.copyWith(
        displaySmall: baseText.displaySmall?.copyWith(fontWeight: FontWeight.w700),
        headlineLarge: baseText.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
        headlineMedium: baseText.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        headlineSmall: baseText.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: baseText.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: baseText.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: baseText.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.notoSans(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: outlineVariant, width: 1),
        ),
        color: surfaceTint,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.notoSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
          elevation: 0,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.notoSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.notoSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.notoSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceTint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceTint,
        selectedItemColor: primary,
        unselectedItemColor: const Color(0xFF9CA39B),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.notoSans(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceTint,
        indicatorColor: primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.notoSans(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: primary,
            );
          }
          return GoogleFonts.notoSans(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: const Color(0xFF6B7168),
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: outlineVariant,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1A1F18),
        contentTextStyle: GoogleFonts.notoSans(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

// Extension for nutrient status colours — maps a measured value against
// defined thresholds and returns the appropriate semantic colour.
extension NutrientColor on double {
  /// Returns a status colour based on thresholds:
  ///  - deficient: value < deficient
  ///  - low: value < adequate
  ///  - adequate: value <= high
  ///  - excess: value > high
  Color nutrientColor(double deficient, double adequate, double high) {
    if (this < deficient) return AppTheme.statusDeficient;
    if (this < adequate) return AppTheme.statusLow;
    if (this <= high)    return AppTheme.statusAdequate;
    return AppTheme.statusExcess;
  }
}
