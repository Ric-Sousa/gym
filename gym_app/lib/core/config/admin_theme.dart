import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme extension que expõe as cores do admin via `Theme.of(context)`.
/// Regista-se no `ThemeData.extensions` para dark e light.
class AdminThemeColors extends ThemeExtension<AdminThemeColors> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color lime;
  final Color limeDim;
  final Color text;
  final Color muted;
  final Color danger;
  final Color blue;
  final Color orange;
  final Color purple;
  final Color green;
  final Color shadow;
  final Color shadowElevated;

  const AdminThemeColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.lime,
    required this.limeDim,
    required this.text,
    required this.muted,
    required this.danger,
    required this.blue,
    required this.orange,
    required this.purple,
    required this.green,
    required this.shadow,
    required this.shadowElevated,
  });

  /// Paleta escura (default).
  static final dark = AdminThemeColors(
    bg: AppColors.adminBg,
    surface: AppColors.adminSurface,
    surface2: AppColors.adminSurface2,
    border: AppColors.adminBorder,
    lime: AppColors.adminLime,
    limeDim: AppColors.adminLimeDim,
    text: AppColors.adminText,
    muted: AppColors.adminMuted,
    danger: AppColors.adminDanger,
    blue: AppColors.adminBlue,
    orange: AppColors.adminOrange,
    purple: AppColors.adminPurple,
    green: AppColors.adminGreen,
    shadow: AppColors.adminShadowDark,
    shadowElevated: AppColors.adminShadowElevatedDark,
  );

  /// Paleta clara.
  static final light = AdminThemeColors(
    bg: AppColors.adminLightBg,
    surface: AppColors.adminLightSurface,
    surface2: AppColors.adminLightSurface2,
    border: AppColors.adminLightBorder,
    lime: AppColors.adminLightLime,
    limeDim: AppColors.adminLightLimeDim,
    text: AppColors.adminLightText,
    muted: AppColors.adminLightMuted,
    danger: AppColors.adminLightDanger,
    blue: AppColors.adminLightBlue,
    orange: AppColors.adminLightOrange,
    purple: AppColors.adminLightPurple,
    green: AppColors.adminLightGreen,
    shadow: AppColors.adminLightShadow,
    shadowElevated: AppColors.adminLightShadowElevated,
  );

  /// Shortcut: `AdminThemeColors.of(context)`.
  static AdminThemeColors of(BuildContext context) {
    return Theme.of(context).extension<AdminThemeColors>() ?? AdminThemeColors.dark;
  }

  @override
  AdminThemeColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? border,
    Color? lime,
    Color? limeDim,
    Color? text,
    Color? muted,
    Color? danger,
    Color? blue,
    Color? orange,
    Color? purple,
    Color? green,
    Color? shadow,
    Color? shadowElevated,
  }) {
    return AdminThemeColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      border: border ?? this.border,
      lime: lime ?? this.lime,
      limeDim: limeDim ?? this.limeDim,
      text: text ?? this.text,
      muted: muted ?? this.muted,
      danger: danger ?? this.danger,
      blue: blue ?? this.blue,
      orange: orange ?? this.orange,
      purple: purple ?? this.purple,
      green: green ?? this.green,
      shadow: shadow ?? this.shadow,
      shadowElevated: shadowElevated ?? this.shadowElevated,
    );
  }

  @override
  AdminThemeColors lerp(AdminThemeColors? other, double t) {
    if (other is! AdminThemeColors) return this;
    return AdminThemeColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      border: Color.lerp(border, other.border, t)!,
      lime: Color.lerp(lime, other.lime, t)!,
      limeDim: Color.lerp(limeDim, other.limeDim, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      orange: Color.lerp(orange, other.orange, t)!,
      purple: Color.lerp(purple, other.purple, t)!,
      green: Color.lerp(green, other.green, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      shadowElevated: Color.lerp(shadowElevated, other.shadowElevated, t)!,
    );
  }
}
