import 'package:flutter/material.dart';

/// Slider interativo de comparação Antes/Depois.
/// Mostra duas imagens lado a lado com uma barra vertical deslizante.
/// Ao arrastar a barra, revela mais da imagem "antes" ou "depois".
class ImageComparisonSlider extends StatefulWidget {
  final String beforeImage;
  final String afterImage;
  final double height;
  final Color? dividerColor;

  const ImageComparisonSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
    this.height = 300,
    this.dividerColor,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  double _sliderPosition = 0.5; // 0.0 = só depois, 1.0 = só antes

  @override
  Widget build(BuildContext context) {
    final color = widget.dividerColor ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final clipRight = width * _sliderPosition;

        return SizedBox(
          height: widget.height,
          width: width,
          child: GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _sliderPosition =
                    (_sliderPosition + details.delta.dx / width).clamp(0.0, 1.0);
              });
            },
            child: Stack(
              children: [
                // ── Imagem "Depois" (fundo) ──
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox.expand(
                    child: Image.network(
                      widget.afterImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Imagem "Antes" (clipada à esquerda) ──
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomLeft: Radius.circular(10),
                  ),
                  child: SizedBox.expand(
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: _sliderPosition,
                        child: Image.network(
                          widget.beforeImage,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Barra divisória ──
                Positioned(
                  left: clipRight - 2,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    color: color,
                  ),
                ),
                // ── Handle (círculo arrastável) ──
                Positioned(
                  left: clipRight - 20,
                  top: widget.height / 2 - 20,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.swipe, size: 20, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
