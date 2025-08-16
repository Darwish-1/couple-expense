import 'package:flutter/material.dart';

class AppColors {
  static const background = Color.fromRGBO(250, 247, 240, 1);
  static const primary    = Color(0xFF1E88E5);
  static const onPrimary  = Colors.white;

  static const textPrimary   = Colors.black87;
  static const textSecondary = Colors.black54;

  static const surface   = Colors.white;
  static const onSurface = Colors.black87;

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFF9A825);
  static const error   = Color(0xFFD32F2F);

  static const chip     = Color(0xFFEDEDED);
  static const chipText = Colors.black87;

  static const divider  = Color(0x1F000000); // 12% black
}
class AppTheme {
  static final ColorScheme _scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    background: AppColors.background,
  ).copyWith(
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
  );

  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorScheme: _scheme,
    scaffoldBackgroundColor: AppColors.background,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),

    // Bottom nav
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.background,
      selectedItemColor: AppColors.textPrimary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),

    // Cards / list items
    cardColor: AppColors.surface,
    cardTheme: const CardThemeData( // ← use *Data
      color: AppColors.surface,
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    // Buttons
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey.shade50, // Set background color to grey.shade50
        foregroundColor: AppColors.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        backgroundColor: Colors.grey.shade50, // Set background color to grey.shade50
        foregroundColor: AppColors.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.grey.shade50, // Set background color to grey.shade50
        foregroundColor: AppColors.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    ),

    // Menus / Dialogs / Chips
    popupMenuTheme: const PopupMenuThemeData(
      color: AppColors.background,
      surfaceTintColor: Colors.transparent,
      textStyle: TextStyle(color: AppColors.textPrimary),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
    ),
    dialogTheme: const DialogThemeData( // ← use *Data
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 14,
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: AppColors.chip,
      labelStyle: TextStyle(color: AppColors.chipText),
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.primary,
      surfaceTintColor: Colors.transparent,
      shape: StadiumBorder(),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _scheme.primary, width: 1.4),
      ),
    ),

    // Icons / text / dividers / progress
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    textTheme: const TextTheme(
      titleLarge: TextStyle(color: AppColors.textPrimary),
      titleMedium: TextStyle(color: AppColors.textPrimary),
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textPrimary),
      bodySmall: TextStyle(color: AppColors.textSecondary),
      labelLarge: TextStyle(color: AppColors.textPrimary),
    ),
    dividerColor: AppColors.divider,
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: _scheme.primary,
    ),
  );
}
