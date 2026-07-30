import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_colors.dart';
import '../../core/services/sound_service.dart';

/// Tipo de notificação.
enum NotificationType { success, error, info }

/// Mostra uma notificação toast no canto superior direito com animação.
void showAppNotification(
  BuildContext context,
  String message, {
  NotificationType type = NotificationType.info,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _ToastWidget(
      message: message,
      type: type,
      duration: duration,
      onRemove: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);

  // Toca o som adequado ao tipo de notificação
  if (type == NotificationType.error) {
    SoundService().playErrorSound();
  } else {
    SoundService().playNotificationChime();
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onRemove;

  const _ToastWidget({
    required this.message,
    required this.type,
    required this.duration,
    required this.onRemove,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Auto-dismiss com fade out após a duração.
    Future.delayed(widget.duration, () {
      if (mounted && !_isDismissing) _dismiss();
    });
  }

  /// Inicia a animação de fade-out e remove o widget após.
  void _dismiss() {
    if (_isDismissing) return;
    _isDismissing = true;
    _controller.reverse().then((_) => widget.onRemove());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _iconColor() {
    switch (widget.type) {
      case NotificationType.success:
        return AppColors.success;
      case NotificationType.error:
        return AppColors.adminDanger;
      case NotificationType.info:
        return AppColors.warning;
    }
  }

  IconData _icon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error_outline;
      case NotificationType.info:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top + 8;

    return Positioned(
      top: topPadding,
      right: 12,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon(), color: _iconColor(), size: 18),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(
                      Icons.close,
                      color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
