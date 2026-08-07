import 'dart:ui';

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
  bool playSound = false,
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

  // Som apenas quando explicitamente solicitado (ex: erros críticos)
  if (playSound) {
    if (type == NotificationType.error) {
      SoundService().playErrorSound();
    } else {
      SoundService().playNotificationChime();
    }
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
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalInset = screenWidth < 420 ? 12.0 : 20.0;

    return Positioned(
      top: topPadding,
      left: screenWidth < 520 ? horizontalInset : null,
      right: horizontalInset,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: screenWidth < 520 ? double.infinity : 380,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHighest.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.65),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 22,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _iconColor().withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_icon(), color: _iconColor(), size: 18),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          widget.message,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _dismiss,
                        tooltip: 'Fechar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        icon: Icon(
                          Icons.close,
                          color: AppColors.onSurfaceVariant.withValues(
                            alpha: 0.6,
                          ),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
