import 'package:flutter/material.dart';

class AppColors {
  static const Color skyBlue = Color(0xFF4FC3F7);
  static const Color skyBlueDark = Color(0xFF0288D1);
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF5FBFF);
  static const Color textDark = Color(0xFF1A2A3A);
  static const Color danger = Color(0xFFE53935);
  static const Color success = Color(0xFF43A047);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.skyBlue,
          primary: AppColors.skyBlueDark,
          background: AppColors.background,
        ),
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.skyBlueDark,
          foregroundColor: AppColors.white,
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.skyBlueDark,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        cardTheme: CardThemeData(
          color: AppColors.white,
          elevation: 6,
          shadowColor: AppColors.skyBlue.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
}
