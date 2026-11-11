import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kPurple = Color(0xFF6C3CE9);
const kPurpleLight = Color(0xFFEFE9FD);
const kBg = Color(0xFFF7F5FC);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kPurple, brightness: Brightness.light).copyWith(
    primary: kPurple,
    surface: Colors.white,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: kBg);
  return base.copyWith(
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: kBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.w800, color: const Color(0xFF1B1530)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: kPurple, width: 1.5)),
      contentPadding: const EdgeInsets.all(16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: kPurpleLight,
      labelTextStyle: WidgetStatePropertyAll(GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: BorderSide.none,
      labelStyle: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600),
    ),
  );
}
