import 'package:flutter/material.dart';

// Catppuccin Mocha palette
class AppColors {
  static const base = Color(0xFF1E1E2E);
  static const mantle = Color(0xFF181825);
  static const crust = Color(0xFF11111B);
  static const surface0 = Color(0xFF313244);
  static const surface1 = Color(0xFF45475A);
  static const surface2 = Color(0xFF585B70);
  static const overlay0 = Color(0xFF6C7086);
  static const overlay1 = Color(0xFF7F849C);
  static const text = Color(0xFFCDD6F4);
  static const subtext0 = Color(0xFFA6ADC8);
  static const subtext1 = Color(0xFFBAC2DE);
  static const blue = Color(0xFF89B4FA);
  static const green = Color(0xFFA6E3A1);
  static const red = Color(0xFFF38BA8);
  static const peach = Color(0xFFFAB387);
  static const yellow = Color(0xFFF9E2AF);
  static const mauve = Color(0xFFCBA6F7);
  static const teal = Color(0xFF94E2D5);
  static const lavender = Color(0xFFB4BEFE);
  static const sapphire = Color(0xFF74C7EC);
}

ThemeData appTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.base,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.blue,
      secondary: AppColors.mauve,
      surface: AppColors.base,
      error: AppColors.red,
      onPrimary: AppColors.crust,
      onSecondary: AppColors.crust,
      onSurface: AppColors.text,
      onError: AppColors.crust,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.mantle,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface0,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface0,
      titleTextStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: const TextStyle(color: AppColors.subtext0, fontSize: 14),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surface0,
      contentTextStyle: TextStyle(color: AppColors.text),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.surface1, thickness: 1),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.green;
        return AppColors.overlay0;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.green.withValues(alpha: 0.3);
        }
        return AppColors.surface1;
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface0,
      hintStyle: const TextStyle(color: AppColors.overlay0),
      labelStyle: const TextStyle(color: AppColors.subtext0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.surface1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.surface1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.blue, width: 2),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.blue,
        foregroundColor: AppColors.crust,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        side: const BorderSide(color: AppColors.surface2),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.blue),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.blue,
    ),
    expansionTileTheme: const ExpansionTileThemeData(
      iconColor: AppColors.subtext0,
      textColor: AppColors.text,
      collapsedTextColor: AppColors.subtext0,
      collapsedIconColor: AppColors.overlay0,
    ),
  );
}
