import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/admin_theme.dart';

/// Shared visual primitives for the Admin workspace.
///
/// These widgets deliberately use surface contrast, spacing and typography as
/// the main hierarchy tools. Borders and shadows stay subtle so pages read as
/// one workspace instead of a collection of unrelated cards.
/// Applies the shared workspace controls used by Admin and Aluno.
///
/// Keeping this in one place prevents the two workspaces from drifting apart:
/// cards, fields, buttons and menus use the same proportions and interaction
/// states while the existing app colors remain untouched.
ThemeData buildWorkspaceTheme(ThemeData baseTheme, AdminThemeColors colors) {
  final subtleButtonBackground = baseTheme.brightness == Brightness.light
      ? colors.text.withValues(alpha: 0.68)
      : colors.surface2.withValues(alpha: 0.22);

  return baseTheme.copyWith(
    scaffoldBackgroundColor: colors.bg,
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.border.withValues(alpha: 0.55)),
      ),
    ),
    inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
      isDense: true,
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide(
          color: baseTheme.colorScheme.primary,
          width: 1.3,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.65),
        elevation: 0,
        minimumSize: const Size(0, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
        backgroundColor: subtleButtonBackground,
        side: const BorderSide(color: Colors.transparent),
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        textStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withValues(alpha: 0.55),
        backgroundColor: subtleButtonBackground,
        minimumSize: const Size(46, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.border.withValues(alpha: 0.65)),
      ),
      titleTextStyle: GoogleFonts.montserrat(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: colors.text,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        height: 1.45,
        color: colors.muted,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}

class AdminDesignTokens {
  AdminDesignTokens._();

  static const pageHorizontal = 28.0;
  static const pageHorizontalCompact = 16.0;
  static const pageTop = 24.0;
  static const pageBottom = 32.0;
  static const sectionGap = 22.0;
  static const controlHeight = 42.0;
  static const radius = 16.0;
  static const smallRadius = 11.0;
}

class AdminPageFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  const AdminPageFrame({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = 1440,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final resolvedPadding =
        padding ??
        EdgeInsets.fromLTRB(
          compact
              ? AdminDesignTokens.pageHorizontalCompact
              : AdminDesignTokens.pageHorizontal,
          compact ? 16 : AdminDesignTokens.pageTop,
          compact
              ? AdminDesignTokens.pageHorizontalCompact
              : AdminDesignTokens.pageHorizontal,
          compact ? 24 : AdminDesignTokens.pageBottom,
        );

    return SingleChildScrollView(
      padding: resolvedPadding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;
  final IconData? icon;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = action != null && constraints.maxWidth < 560;
        final titleRow = Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: colors.lime),
              const SizedBox(width: 10),
            ],
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
            ),
          ],
        );
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleRow,
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: colors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 14), action!],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: copy),
            if (action != null) ...[const SizedBox(width: 16), action!],
          ],
        );
      },
    );
  }
}

class AdminSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final bool emphasized;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const AdminSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color,
    this.emphasized = false,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AdminDesignTokens.radius),
    ),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final surfaceColor =
        color ?? (emphasized ? colors.surface2 : colors.surface);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: colors.border.withValues(alpha: emphasized ? 0.72 : 0.48),
        ),
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, borderRadius: borderRadius, child: content),
    );
  }
}

class AdminToolbar extends StatelessWidget {
  final Widget child;

  const AdminToolbar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AdminSurface(
      padding: const EdgeInsets.all(8),
      color: AdminThemeColors.of(context).bg,
      borderRadius: BorderRadius.circular(AdminDesignTokens.smallRadius),
      child: child,
    );
  }
}

class AdminMetric extends StatelessWidget {
  final String label;
  final String value;
  final String? detail;
  final IconData icon;
  final Color? accent;

  const AdminMetric({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final color = accent ?? colors.lime;
    return AdminSurface(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: colors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: GoogleFonts.montserrat(
                    color: colors.text,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    detail!,
                    style: GoogleFonts.inter(fontSize: 10, color: colors.muted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const AdminSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: GoogleFonts.inter(fontSize: 11, color: colors.muted),
                ),
              ],
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
