import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette - Deep Purple/Teal Gradient Theme
  static const Color primaryPurple = Color(0xFF6366F1); // Indigo
  static const Color primaryTeal = Color(0xFF14B8A6); // Teal
  static const Color accentOrange = Color(0xFFF59E0B); // Amber

  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color backgroundDark = Color(0xFF0F172A);

  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E293B);

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color.fromARGB(255, 86, 106, 134);
  static const Color textDark = Color(0xFFF1F5F9);

  static const Color successGreen = Color(0xFF10B981);
  static const Color errorRed = Color(0xFFEF4444);
  static const Color warningYellow = Color(0xFFF59E0B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFF8FAFC), Color(0xFFE0E7FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryPurple,
      secondary: primaryTeal,
      tertiary: accentOrange,
      surface: cardLight,
      background: backgroundLight,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textPrimary,
      onBackground: textPrimary,
    ),
    scaffoldBackgroundColor: backgroundLight,

    // Typography
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: textSecondary,
      ),
    ),

    // App Bar Theme
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textPrimary,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardLight,
      shadowColor: Colors.black.withOpacity(0.1),
    ),

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: backgroundLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryPurple, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardLight,
      selectedItemColor: primaryPurple,
      unselectedItemColor: textSecondary,
      selectedLabelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );

  // Dark Theme
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryPurple,
      secondary: primaryTeal,
      tertiary: accentOrange,
      surface: cardDark,
      background: backgroundDark,
      error: errorRed,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: textDark,
      onBackground: textDark,
    ),
    scaffoldBackgroundColor: backgroundDark,

    // Typography (Dark)
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textDark,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textDark,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      titleLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textDark,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        color: textDark,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: textSecondary,
      ),
    ),

    // App Bar Theme (Dark)
    appBarTheme: AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Colors.transparent,
      foregroundColor: textDark,
      titleTextStyle: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textDark,
      ),
    ),

    // Card Theme (Dark)
    cardTheme: CardThemeData(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cardDark,
      shadowColor: Colors.black.withOpacity(0.3),
    ),

    // Button Themes (Dark)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // Input Decoration Theme (Dark)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade800),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryPurple, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),

    // Bottom Navigation Bar Theme (Dark)
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: cardDark,
      selectedItemColor: primaryPurple,
      unselectedItemColor: textSecondary,
      selectedLabelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 12,
      ),
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}
