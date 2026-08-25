import 'package:flutter/material.dart';

// SyncWatch brand palette (mirrors the web design tokens).
class Sw {
  static const bg = Color(0xFF080B16);
  static const bg2 = Color(0xFF0B0F1E);
  static const surface = Color(0xFF101627);
  static const surfaceRaised = Color(0xFF161D33);
  static const border = Color(0xFF232C47);
  static const text = Color(0xFFEEF2FB);
  static const muted = Color(0xFF97A1BD);
  static const violet = Color(0xFF8B5CF6);
  static const blue = Color(0xFF3B82F6);
  static const accent = Color(0xFF7C6CFF);
  static const danger = Color(0xFFFF5D76);
  static const success = Color(0xFF34E0A1);

  static const gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, blue],
  );
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Segoe UI',
    scaffoldBackgroundColor: Sw.bg,
    colorScheme: const ColorScheme.dark(
      primary: Sw.accent,
      surface: Sw.surface,
      error: Sw.danger,
    ),
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(backgroundColor: Sw.bg2, foregroundColor: Sw.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Sw.surfaceRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Sw.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Sw.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Sw.accent,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
