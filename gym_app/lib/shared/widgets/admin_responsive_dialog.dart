import 'package:flutter/material.dart';
import '../../core/config/admin_theme.dart';
import '../../core/config/app_strings.dart';

/// Modal responsivo e consistente para a área administrativa.
class AdminResponsiveDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final List<Widget> actions;
  final double maxWidth;

  const AdminResponsiveDialog({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.maxWidth = 620,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final isCompact = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 28,
        vertical: isCompact ? 16 : 28,
      ),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Material(
            color: colors.surface,
            borderRadius: BorderRadius.circular(isCompact ? 22 : 28),
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            shadowColor: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DialogHeader(
                  title: title,
                  subtitle: subtitle,
                  icon: icon,
                  onClose: () => Navigator.of(context).pop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 18 : 26,
                      4,
                      isCompact ? 18 : 26,
                      22,
                    ),
                    child: child,
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  Divider(height: 1, color: colors.border),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isCompact ? 16 : 22,
                      14,
                      isCompact ? 16 : 22,
                      isCompact ? 16 : 20,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback onClose;

  const _DialogHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colors.limeDim,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: colors.lime, size: 20),
            ),
            const SizedBox(width: 13),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      Theme.of(context).dialogTheme.titleTextStyle ??
                      TextStyle(
                        color: colors.text,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: colors.muted,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.cancel,
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, color: colors.muted, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: colors.surface2,
              minimumSize: const Size(38, 38),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Versão compatível com a API de [AlertDialog], mas responsiva.
class AdminResponsiveAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget> actions;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final EdgeInsetsGeometry? contentPadding;

  const AdminResponsiveAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions = const [],
    this.backgroundColor,
    this.shape,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    final compact = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 28,
        vertical: compact ? 16 : 28,
      ),
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 620,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Material(
            color: backgroundColor ?? colors.surface,
            shape:
                shape ??
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(compact ? 22 : 28),
                  side: BorderSide(color: colors.border.withValues(alpha: 0.9)),
                ),
            elevation: 0,
            shadowColor: Colors.transparent,
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 16, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: DefaultTextStyle(
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                          child: title ?? const SizedBox.shrink(),
                        ),
                      ),
                      IconButton(
                        tooltip: AppStrings.cancel,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: colors.muted,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: colors.surface2,
                          minimumSize: const Size(38, 38),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding:
                        contentPadding ??
                        EdgeInsets.fromLTRB(
                          compact ? 18 : 26,
                          0,
                          compact ? 18 : 26,
                          22,
                        ),
                    child: content ?? const SizedBox.shrink(),
                  ),
                ),
                if (actions.isNotEmpty) ...[
                  Divider(height: 1, color: colors.border),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 22,
                      14,
                      compact ? 16 : 22,
                      compact ? 16 : 20,
                    ),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 10,
                        runSpacing: 8,
                        children: actions,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo visual compacto para secções dentro de um modal administrativo.
class AdminDialogSection extends StatelessWidget {
  final String title;
  final Widget child;

  const AdminDialogSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: colors.lime,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

ButtonStyle adminDialogCancelStyle(BuildContext context) {
  return TextButton.styleFrom(
    foregroundColor: Colors.white,
    minimumSize: const Size(92, 44),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

ButtonStyle adminDialogPrimaryStyle(BuildContext context) {
  final colors = AdminThemeColors.of(context);
  return ElevatedButton.styleFrom(
    backgroundColor: colors.lime,
    foregroundColor: Colors.white,
    minimumSize: const Size(110, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
