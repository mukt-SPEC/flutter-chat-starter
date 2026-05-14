import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const primaryDark = Color(0xFF121212);
  static const surfaceLight = Color(0xFFF7F7F7);
  static const greyMedium = Color(0xFFB9B9B9);
  static const white = Color(0xFFFFFFFF);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryDark,
      scaffoldBackgroundColor: surfaceLight,
      colorScheme: const ColorScheme.light(
        primary: primaryDark,
        onPrimary: white,
        secondary: primaryDark,
        onSecondary: white,
        surface: white,
        onSurface: primaryDark,
        outline: greyMedium,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryDark,
        foregroundColor: white,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryDark,
        foregroundColor: white,
        elevation: 0,
        hoverElevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        shape: CircleBorder(),
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        headlineLarge: const TextStyle(
          color: primaryDark,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: const TextStyle(
          color: primaryDark,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: const TextStyle(
          color: primaryDark,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(color: primaryDark),
        bodyMedium: const TextStyle(color: primaryDark),
      ),
      dividerTheme: const DividerThemeData(
        color: greyMedium,
        thickness: 0.5,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: greyMedium),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: greyMedium),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryDark, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryDark,
          foregroundColor: white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
