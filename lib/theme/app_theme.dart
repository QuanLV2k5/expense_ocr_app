import 'package:flutter/material.dart';

import '../models/expense_category.dart';

class AppTheme {
  static const ink = Color(0xFF152C38);
  static const primary = Color(0xFF087F8C);
  static const background = Color(0xFFF3F6F8);
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      primary: primary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: ink,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: ink,
        fontWeight: FontWeight.w700,
        fontSize: 23,
      ),
      titleMedium: TextStyle(
        color: ink,
        fontWeight: FontWeight.w700,
        fontSize: 17,
      ),
      bodyMedium: TextStyle(color: ink, fontSize: 14, height: 1.4),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 3,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE9EFF2)),
  );
  static IconData categoryIcon(ExpenseCategory category) => switch (category) {
    ExpenseCategory.food => Icons.restaurant_rounded,
    ExpenseCategory.study => Icons.school_rounded,
    ExpenseCategory.travel => Icons.flight_rounded,
    ExpenseCategory.device => Icons.devices_rounded,
    ExpenseCategory.entertainment => Icons.movie_rounded,
  };
  static Color categoryColor(ExpenseCategory category) => [
    primary,
    const Color(0xFF7274DA),
    const Color(0xFFE3A13D),
    const Color(0xFF5C8ED6),
    const Color(0xFFDD7896),
  ][category.index];
}
