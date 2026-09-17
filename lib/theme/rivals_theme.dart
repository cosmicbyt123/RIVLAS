import 'package:flutter/material.dart';

class RivalsTheme {
  // Brand Colors
  static const Color background = Color(0xFF0D0F0D);
  static const Color surface = Color(0xFF141814);
  static const Color surfaceElevated = Color(0xFF1B201B);
  static const Color surfaceHighlight = Color(0xFF242C24);
  
  // Neon Cyber Volt / Lime Accent
  static const Color neonLime = Color(0xFFCCFF00);
  static const Color neonLimeDark = Color(0xFFA8D400);
  static const Color neonLimeGlow = Color(0x55CCFF00);
  static const Color neonLimeSubtle = Color(0x1FCCFF00);

  // Status & Utility Colors
  static const Color verifiedGreen = Color(0xFF22C55E);
  static const Color warningOrange = Color(0xFFFF9900);
  static const Color dangerRed = Color(0xFFFF3B30);
  static const Color trophyGold = Color(0xFFFFD700);
  static const Color cyanAccent = Color(0xFF00E5FF);

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8B0);
  static const Color textMuted = Color(0xFF6B756B);

  // Border Colors
  static const Color borderLight = Color(0x14FFFFFF);
  static const Color borderNeon = Color(0x40CCFF00);

  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: background,
      primaryColor: neonLime,
      colorScheme: const ColorScheme.dark(
        primary: neonLime,
        secondary: neonLime,
        surface: surface,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
    );
  }

  // Common Box Decorations
  static BoxDecoration cardDecoration({
    Color? color,
    BorderRadius? borderRadius,
    bool glow = false,
    bool activeBorder = false,
  }) {
    return BoxDecoration(
      color: color ?? surface,
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      border: Border.all(
        color: activeBorder ? neonLime : (glow ? borderNeon : borderLight),
        width: activeBorder ? 1.5 : 1.0,
      ),
      boxShadow: glow
          ? [
              BoxShadow(
                color: neonLime.withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }
}
