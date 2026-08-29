/// AtaKonitena 主题。
library;

import 'package:flutter/material.dart';

class AtaTheme {
  static const seed = Color(0xFF2E6BFF);
  static const accent = Color(0xFF00C2A8);

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF0E1116),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF161B22),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: const Color(0xFF10141B),
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme:
            const IconThemeData(color: Color(0xFF8B93A1)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1C222C),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      dividerColor: const Color(0xFF232A34),
    );
  }
}