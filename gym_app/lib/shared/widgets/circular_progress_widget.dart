import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';

/// Indicador circular de progresso (água, passos, etc.).
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
    this.backgroundColor = const Color(0xFFE0E0E0),
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
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Círculo de progresso
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: CircularProgressIndicator(
                    value: clampedValue,
                    strokeWidth: 8,
                    backgroundColor: backgroundColor,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 10,
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
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            goalValue,
            style: const TextStyle(
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
                  style: TextStyle(fontSize: 12, color: color),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
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
