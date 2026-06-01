import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static Color hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF1A237E);
    }
  }

  static ThemeData createTheme({
    required String primaryHex,
    required String accentHex,
    required String backgroundHex,
    required String cardHex,
    required String textPrimaryHex,
    required String textSecondaryHex,
    bool isDark = false,
  }) {
    final primary = hexToColor(primaryHex);
    final accent = hexToColor(accentHex);
    final background = isDark ? const Color(0xFF0F172A) : hexToColor(backgroundHex);
    final card = isDark ? const Color(0xFF1E293B) : hexToColor(cardHex);
    final textPrimary = isDark ? Colors.white : hexToColor(textPrimaryHex);
    
    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: primary,
        secondary: accent,
        surface: card,
        onSurface: textPrimary,
      ),
      textTheme: (isDark 
        ? GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)
        : GoogleFonts.poppinsTextTheme()
      ).apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0F172A) : background,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get lightTheme => createTheme(
    primaryHex: '#1A237E',
    accentHex: '#FFC107',
    backgroundHex: '#F8FAFC',
    cardHex: '#FFFFFF',
    textPrimaryHex: '#0F172A',
    textSecondaryHex: '#64748B',
  );
}
