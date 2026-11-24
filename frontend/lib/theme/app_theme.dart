import 'package:flutter/material.dart';

/// Colores inspirados en el póster de SmartCompost (INNOVATEC VI):
/// verdes de hoja, fondo crema-lima y café de la tierra del logo.
class AppColors {
  static const background = Color(0xFFF5F9E3); // crema lima del póster
  static const surface = Color(0xFFFFFFF7); // tarjetas
  static const surfaceInput = Color(0xFFEEF5D3);
  static const border = Color(0xFFCFE2A0);
  static const accent = Color(0xFF3F8A24); // verde botones
  static const accentDark = Color(0xFF2B6318); // verde encabezados
  static const lima = Color(0xFFA9D046);
  static const limaClara = Color(0xFFDCEDA6);
  static const amarillo = Color(0xFFE8F046); // "¡Escanea y conoce cómo funciona!"
  static const cafe = Color(0xFF7A4E2A); // tierra del logo
  static const textPrimary = Color(0xFF1E3512);
  static const textSecondary = Color(0xFF4E6A3B);
  static const textMuted = Color(0xFF7B8E69);
}

class AppFonts {
  /// Fuente redondeada y gruesa para los títulos, como en el póster.
  static const titulo = 'LilitaOne';
}

/// Degradado verde de los encabezados del póster.
const LinearGradient kDegradadoVerde = LinearGradient(
  colors: [AppColors.accentDark, AppColors.accent, Color(0xFF6AAA35)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class AppTheme {
  static ThemeData get claro {
    final redondeado = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        primary: AppColors.accent,
        secondary: AppColors.lima,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.accentDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.titulo,
          fontSize: 22,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
      cardTheme: CardThemeData(color: AppColors.surface, shape: redondeado),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        titleTextStyle: const TextStyle(
            fontFamily: AppFonts.titulo, fontSize: 22, color: AppColors.accentDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceInput,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
      // Botones tipo "píldora", bien redondeados.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: AppColors.accentDark.withValues(alpha: 0.4),
          minimumSize: const Size.fromHeight(48),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentDark,
          side: const BorderSide(color: AppColors.accent, width: 1.6),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentDark,
          shape: const StadiumBorder(),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textSecondary,
          selectedBackgroundColor: AppColors.accent,
          selectedForegroundColor: Colors.white,
          side: const BorderSide(color: AppColors.accent),
          shape: const StadiumBorder(),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.accent,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        checkmarkColor: Colors.white,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        shape: StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border),
      // Transición suave al abrir pantallas.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
      }),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: AppColors.textPrimary),
      ),
    );
  }
}
