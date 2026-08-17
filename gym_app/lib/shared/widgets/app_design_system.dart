import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config/admin_theme.dart';

/// Mostra um seletor de data com espaçamento explícito entre os botões e a
/// borda do modal. O DatePicker nativo do Flutter fixa essa margem em 8 px.
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialDate,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
  String? helpText,
  String? cancelText,
  String? confirmText,
  TransitionBuilder? builder,
}) {
  final dialog = _AppDatePickerDialog(
    firstDate: DateUtils.dateOnly(firstDate),
    lastDate: DateUtils.dateOnly(lastDate),
    initialDate: initialDate == null ? null : DateUtils.dateOnly(initialDate),
    initialDatePickerMode: initialDatePickerMode,
    helpText: helpText,
    cancelText: cancelText,
    confirmText: confirmText,
  );

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      final child = dialog;
      return builder?.call(dialogContext, child) ?? child;
    },
  );
}

class _AppDatePickerDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialDate;
  final DatePickerMode initialDatePickerMode;
  final String? helpText;
  final String? cancelText;
  final String? confirmText;

  const _AppDatePickerDialog({
    required this.firstDate,
    required this.lastDate,
    required this.initialDate,
    required this.initialDatePickerMode,
    this.helpText,
    this.cancelText,
    this.confirmText,
  });

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime? _selectedDate;
  late final TextEditingController _inputController;
  bool _inputMode = false;
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _inputController = TextEditingController(text: _formatInput(widget.initialDate));
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String _formatInput(DateTime? date) {
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  DateTime? _parseInput() {
    final parts = _inputController.text.trim().split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return DateUtils.dateOnly(parsed);
  }

  void _confirm() {
    final date = _inputMode ? _parseInput() : _selectedDate;
    if (date == null || date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate)) {
      setState(() => _inputError = 'Seleciona uma data válida.');
      return;
    }
    Navigator.of(context).pop(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datePickerTheme = theme.datePickerTheme;
    final colors = theme.colorScheme;
    final selectedLabel = _selectedDate == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(_selectedDate!);
    final shape = datePickerTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(28));

    return Dialog(
      backgroundColor: datePickerTheme.backgroundColor ?? colors.surface,
      surfaceTintColor: datePickerTheme.surfaceTintColor ?? Colors.transparent,
      shape: shape,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.helpText ?? 'Seleciona a data',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          selectedLabel,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: _inputMode ? 'Calendário' : 'Introduzir data',
                    onPressed: () => setState(() {
                      _inputMode = !_inputMode;
                      _inputError = null;
                      _inputController.text = _formatInput(_selectedDate);
                    }),
                    icon: Icon(
                      _inputMode ? Icons.calendar_today : Icons.edit_outlined,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant.withValues(alpha: 0.35)),
            if (_inputMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: TextField(
                  controller: _inputController,
                  autofocus: true,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Data (DD/MM/AAAA)',
                    errorText: _inputError,
                  ),
                  onChanged: (_) {
                    if (_inputError != null) setState(() => _inputError = null);
                  },
                ),
              )
            else
              CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                initialCalendarMode: widget.initialDatePickerMode,
                onDateChanged: (date) => setState(() {
                  _selectedDate = date;
                  _inputController.text = _formatInput(date);
                }),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(widget.cancelText ?? 'Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _confirm,
                    child: Text(widget.confirmText ?? 'Confirmar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tokens visuais usados pelas superfícies novas sem criar uma paleta paralela.
class AppDesignTokens {
  AppDesignTokens._();

  // Same proportions used by the Admin workspace.
  static const radiusSmall = 11.0;
  static const radiusMedium = 18.0;
  static const radiusLarge = 26.0;
  static const pageGap = 20.0;
  static const sectionGap = 22.0;
}

/// Superfície principal para secções de produto.
class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final bool elevated;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.color,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(AppDesignTokens.radiusMedium),
    ),
    this.onTap,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).colorScheme.surface,
        borderRadius: borderRadius,
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.55),
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: child,
    );

    final animatedContent = ScrollReveal(child: content);
    if (onTap == null) return animatedContent;
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: animatedContent,
      ),
    );
  }
}

/// Revela conteúdo quando entra na área visível de um scroll.
/// Não depende de plugins externos e pode ser usado dentro de qualquer
/// ScrollView/ListView existente.
class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;

  const ScrollReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.06),
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal> {
  bool _visible = false;
  bool _visibilityScheduled = false;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextPosition = Scrollable.maybeOf(context)?.position;
    if (identical(_scrollPosition, nextPosition)) return;
    _scrollPosition?.removeListener(_handleScroll);
    _scrollPosition = nextPosition;
    _scrollPosition?.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    _checkVisibility();
  }

  bool _checkVisibility() {
    if (!mounted || _visible) return _visible;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return false;
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final bottom = top + renderObject.size.height;
    final height = MediaQuery.sizeOf(context).height;
    if (bottom > 0 && top < height && !_visibilityScheduled) {
      _visibilityScheduled = true;
      Future<void>.delayed(widget.delay, () {
        if (!mounted) return;
        if (!_visible) setState(() => _visible = true);
        _visibilityScheduled = false;
      });
    }
    return _visible;
  }

  bool _onScroll(ScrollNotification notification) {
    _checkVisibility();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.of(context).disableAnimations
        ? Duration.zero
        : widget.duration;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: duration,
        curve: Curves.easeOutCubic,
        child: AnimatedSlide(
          offset: _visible ? Offset.zero : widget.beginOffset,
          duration: duration,
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Fade e pequeno slide usados quando se troca de página ou conversa.
class FadeSlideSwitcher extends StatelessWidget {
  final Widget child;
  final Duration duration;

  const FadeSlideSwitcher({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSwitcher(
      duration: reduceMotion ? Duration.zero : duration,
      reverseDuration: reduceMotion ? Duration.zero : duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Cabeçalho de página com hierarquia consistente e ação opcional.
class AppPageIntro extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? action;

  const AppPageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = action != null && constraints.maxWidth < 520;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.14,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            Text(title, style: textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: textTheme.bodySmall),
            ],
          ],
        );

        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [copy, const SizedBox(height: 16), action!],
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

class AppMetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color? accent;

  const AppMetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return AppSurface(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(AppDesignTokens.radiusSmall),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 22),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(detail!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class AppStatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const AppStatusPill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mantém todas as páginas montadas sem pintar páginas invisíveis.
/// A troca de aba é imediata para evitar que árvores pesadas (chat, calendário
/// e formulários) concorram pelo frame durante a navegação.
class AnimatedIndexedStack extends StatelessWidget {
  final int index;
  final List<Widget> children;

  const AnimatedIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < children.length; i++)
          Offstage(
            offstage: i != index,
            child: TickerMode(enabled: i == index, child: children[i]),
          ),
      ],
    );
  }
}

class StudentNavigationRail extends StatelessWidget {
  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final int chatUnreadCount;
  final String? chatPreview;

  const StudentNavigationRail({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.chatUnreadCount = 0,
    this.chatPreview,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          right: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    color: scheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'GYMBT',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 38),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'ÁREA DO ALUNO',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.14,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 10),
          ...destinations.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final selected = index == selectedIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Material(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.13)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: () => onDestinationSelected(index),
                  borderRadius: BorderRadius.circular(15),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        _NavigationIcon(
                          icon: _destinationIcon(item, selected),
                          color: selected
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          badge: index == 4 ? chatUnreadCount : 0,
                          preview: index == 4 ? chatPreview : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        if (selected)
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: scheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          AppSurface(
            padding: const EdgeInsets.all(13),
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 17, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Mantém o ritmo',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

IconData? _destinationIcon(NavigationDestination destination, bool selected) {
  final icon = selected ? destination.selectedIcon : destination.icon;
  return icon is Icon ? icon.icon : null;
}

class _NavigationIcon extends StatelessWidget {
  final IconData? icon;
  final Color color;
  final int badge;
  final String? preview;

  const _NavigationIcon({
    required this.icon,
    required this.color,
    required this.badge,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 19, color: color),
        if (badge > 0) ...[
          if (preview != null && preview!.isNotEmpty)
            Positioned(
              top: -24,
              right: -48,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 145),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: Text(
                      preview!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: -7,
            right: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 15, minHeight: 15),
              padding: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badge > 99 ? '99+' : '$badge',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class StudentFloatingDock extends StatelessWidget {
  final int selectedIndex;
  final List<NavigationDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final int chatUnreadCount;
  final String? chatPreview;

  const StudentFloatingDock({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
    this.chatUnreadCount = 0,
    this.chatPreview,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 390;
          return Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: destinations.asMap().entries.map((entry) {
                final selected = entry.key == selectedIndex;
                final item = entry.value;
                return Expanded(
                  child: InkWell(
                    onTap: () => onDestinationSelected(entry.key),
                    borderRadius: BorderRadius.circular(18),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primary.withValues(alpha: 0.14)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _NavigationIcon(
                            icon: _destinationIcon(item, selected),
                            color: selected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                            badge: entry.key == 4 ? chatUnreadCount : 0,
                            preview: entry.key == 4 ? chatPreview : null,
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class AdminWorkspaceHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? action;

  const AdminWorkspaceHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AdminThemeColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(32, 20, 28, 18),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(color: colors.border.withValues(alpha: 0.75)),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.limeDim,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'ADMIN',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                          color: colors.lime,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: colors.text,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: colors.muted),
                ),
              ],
            ),
          ),
          if (action != null) action!,
          const SizedBox(width: 12),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.limeDim,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              size: 19,
              color: colors.lime,
            ),
          ),
        ],
      ),
    );
  }
}
