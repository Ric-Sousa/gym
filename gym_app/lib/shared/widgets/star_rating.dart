import 'package:flutter/material.dart';
import '../../core/config/app_colors.dart';

/// Componente de avaliação por estrelas (1-5).
class StarRating extends StatelessWidget {
  final int rating;
  final int maxRating;
  final double size;
  final ValueChanged<int>? onChanged;
  final bool interactive;
  final Color filledColor;
  final Color emptyColor;

  const StarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 36,
    this.onChanged,
    this.interactive = true,
    this.filledColor = AppColors.starFilled,
    this.emptyColor = AppColors.starEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(maxRating, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= rating;
        return GestureDetector(
          onTap: interactive && onChanged != null
              ? () => onChanged!(starIndex)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedScale(
              scale: isFilled ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isFilled ? Icons.star : Icons.star_border,
                size: size,
                color: isFilled ? filledColor : emptyColor,
              ),
            ),
          ),
        );
      }),
    );
  }
}
