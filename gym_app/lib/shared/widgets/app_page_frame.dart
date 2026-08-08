import 'package:flutter/material.dart';

/// Content frame shared by full-screen views.
///
/// Keeps content readable on wide displays while preserving comfortable
/// gutters on tablets and phones. It only controls presentation; it does not
/// introduce scrolling or change the screen's state.
class AppPageFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final Alignment alignment;

  const AppPageFrame({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    this.alignment = Alignment.topCenter,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Consistent title block for page sections.
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 520 && action != null;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: textTheme.headlineSmall),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: textTheme.bodySmall),
            ],
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 14), action!],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: copy),
            if (action != null) ...[const SizedBox(width: 16), action!],
          ],
        );
      },
    );
  }
}
