import 'package:flutter/material.dart';

/// Paleta de cores "Kinetic Dark" — design system de alta performance.
/// Inspirado pelo DESIGN.md do Stitch.
class AppColors {
  AppColors._();

  // ── Background & Surfaces ──────────────────────────────────────
  /// Fundo principal (OLED-optimized black).
  static const Color background = Color(0xFF111508);

  /// Container mais baixo.
  static const Color surfaceLowest = Color(0xFF0C0F04);

  /// Container baixo.
  static const Color surfaceLow = Color(0xFF1A1D10);

  /// Container padrão.
  static const Color surface = Color(0xFF1E2113);

  /// Container alto.
  static const Color surfaceHigh = Color(0xFF282B1D);

  /// Container mais alto.
  static const Color surfaceHighest = Color(0xFF333627);

  // ── Texto ──────────────────────────────────────────────────────
  /// Texto principal sobre superfícies escuras.
  static const Color onSurface = Color(0xFFE2E4CF);

  /// Texto secundário / muted.
  static const Color onSurfaceVariant = Color(0xFFC4C9AC);

  /// Texto sobre fundo escuro (usado como subtítulo).
  static const Color textPrimary = Color(0xFFE2E4CF);

  /// Texto secundário.
  static const Color textSecondary = Color(0xFF8E9379);

  /// Texto sobre cor primária.
  static const Color textOnPrimary = Colors.white;

  // ── Primary (Cyber Magenta) ────────────────────────────────────
  /// Cor primária - ações principais, progresso, foco.
  static const Color primary = Color(0xFFB20C7E);

  /// Container da cor primária.
  static const Color primaryContainer = Color(0xFFFFD8E8);

  /// Texto sobre o container primário.
  static const Color onPrimaryContainer = Color(0xFFBA1885);

  /// Variante fixa.
  static const Color primaryFixed = Color(0xFFFFD8E8);
  static const Color primaryFixedDim = Color(0xFFFFAFD6);

  // ── Secondary ──────────────────────────────────────────────────
  static const Color secondary = Color(0xFFC8C6C5);
  static const Color onSecondary = Color(0xFF313030);
  static const Color secondaryContainer = Color(0xFF474746);
  static const Color onSecondaryContainer = Color(0xFFB7B5B4);
  static const Color secondaryFixedDim = Color(0xFFC8C6C5);

  // ── Tertiary ───────────────────────────────────────────────────
  static const Color tertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFD2E5F5);
  static const Color onTertiaryContainer = Color(0xFF556774);

  // ── Outlines ───────────────────────────────────────────────────
  /// Contorno de cartões.
  static const Color outline = Color(0xFF444933);

  /// Contorno secundário.
  static const Color outlineVariant = Color(0xFF8E9379);

  // ── Semantic ───────────────────────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color error = Color(0xFFFFB4AB);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onError = Color(0xFF690005);
  static const Color info = Color(0xFF2196F3);

  // ── Dashboard métricas (mantendo cores distintas) ──────────────
  /// Água - cyan mantido para contraste.
  static const Color water = Color(0xFF03A9F4);
  static const Color waterLight = Color(0xFF1A3A4A);

  /// Calorias - laranja mantido.
  static const Color calories = Color(0xFFFF5722);
  static const Color caloriesLight = Color(0xFF3A2018);

  /// Passos - verde mantido.
  static const Color steps = Color(0xFF8BC34A);
  static const Color stepsLight = Color(0xFF1A2E10);

  // ── Rating stars ───────────────────────────────────────────────
  static const Color starFilled = Color(0xFFFFB300);
  static const Color starEmpty = Color(0xFF444933);

  // ── Admin ──────────────────────────────────────────────────────
  static const Color adminPrimary = Color(0xFF37474F);
  static const Color adminAccent = Color(0xFF00BCD4);

  // ── Admin Design System (Figma: "GYMBT") ────────────────────────
  static const Color adminBg = Color(0xFF0B0B0E);
  static const Color adminSurface = Color(0xFF131318);
  static const Color adminSurface2 = Color(0xFF1C1C24);
  static const Color adminBorder = Color(0x12FFFFFF);
  static const Color adminLime = Color(0xFFC8F20D);
  static const Color adminLimeDim = Color(0x1EC8F20D);
  static const Color adminText = Color(0xFFF0F0F5);
  static const Color adminMuted = Color(0xFF6B6B7A);
  static const Color adminDanger = Color(0xFFF25C5C);
  static const Color adminBlue = Color(0xFF4D9CFF);
  static const Color adminOrange = Color(0xFFFF8C42);
  static const Color adminPurple = Color(0xFFB97CFF);

  // ── Glassmorphism ──────────────────────────────────────────────
  /// Cor para overlays com efeito de vidro (60% opacidade).
  static Color glassOverlay = surfaceHighest.withValues(alpha: 0.6);

  // ── Legacy aliases (compatibilidade) ───────────────────────────
  static const Color primaryLight = primary;
  static const Color primaryDark = Color(0xFF8A0060);
  static const Color accent = primary;
  static const Color accentLight = Color(0xFFFFAFD6);
  static const Color backgroundLight = background;
  static const Color backgroundDark = background;
  static const Color surfaceLight = surface;
  static const Color surfaceDark = surfaceHighest;
}
