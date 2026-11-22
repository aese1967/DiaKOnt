import 'package:material_ui/material_ui.dart';

/// Paleta de marca DiaKont: azul profundo (confianza) + esmeralda (finanzas).
class BrandColors {
  BrandColors._();
  static const navy = Color(0xFF0B2A55);
  static const blue = Color(0xFF1456C8);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  /// Degradado de las tarjetas destacadas del dashboard.
  static const heroGradient = LinearGradient(
    colors: [navy, blue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Paleta para categorías y grupos nuevos (también usada en los gráficos).
  static const palette = <Color>[
    Color(0xFFF59E0B),
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFFF97316),
    Color(0xFF10B981),
    Color(0xFFEC4899),
    Color(0xFF14B8A6),
    Color(0xFF84CC16),
    Color(0xFF64748B),
    Color(0xFF1456C8),
  ];
}

/// Temas claro y oscuro estilo fintech: superficies limpias, bordes suaves,
/// tarjetas redondeadas y tipografía con buen contraste.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: BrandColors.blue,
      brightness: brightness,
      primary: isDark ? const Color(0xFF7FB0FF) : BrandColors.blue,
      secondary: BrandColors.emerald,
      error: BrandColors.danger,
      surface: isDark ? const Color(0xFF0E1523) : const Color(0xFFF6F8FC),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark ? const Color(0xFF162033) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: isDark ? const Color(0xFF223049) : const Color(0xFFE6EAF2),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF162033) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BrandColors.emerald,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.primary.withValues(alpha: 0.15),
      ),
    );
  }
}
