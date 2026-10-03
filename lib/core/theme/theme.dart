import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.indigo,
      scaffoldBackgroundColor: AppColors.bgPrimary,
      fontFamily: 'Inter',
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.indigo,
        secondary: AppColors.violet,
        surface: AppColors.bgCard,
        error: AppColors.pdfColor,
      ),
    );
  }
}
