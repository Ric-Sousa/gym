import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/config/app_colors.dart';

/// Indicador circular de progresso (água, passos, etc.) — Kinetic Dark.
class CircularProgressWidget extends StatelessWidget {
  final double value; // 0.0 a 1.0
  final String label;
  final String currentValue;
  final String goalValue;
  final String unit;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final VoidCallback? onIncrement;
  final String? incrementLabel;

  const CircularProgressWidget({
    super.key,
    required this.value,
    required this.label,
    required this.currentValue,
    required this.goalValue,
    this.unit = '',
    required this.color,
    this.backgroundColor = const Color(0xFF333627),
    required this.icon,
    this.onIncrement,
    this.incrementLabel,
  });

  @override
  Widget build(BuildContext context) {
    final clampedValue = value.clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: AppColors.surfaceLowest.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Círculo de progresso
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: clampedValue,
                    strokeWidth: 8,
                    backgroundColor: AppColors.outline,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(height: 2),
                    Text(
                      currentValue,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.onSurface,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        unit,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurface,
            ),
          ),
          Text(
            goalValue,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          if (onIncrement != null && incrementLabel != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onIncrement,
                icon: Icon(Icons.add_circle_outline, size: 16, color: color),
                label: Text(
                  incrementLabel!,
                  style: GoogleFonts.inter(fontSize: 12, color: color),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
