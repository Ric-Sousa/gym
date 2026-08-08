import 'package:flutter/material.dart';

/// Slider interativo de comparação Antes/Depois.
/// A imagem de fundo é a versão mais recente e a imagem da frente é recortada
/// pela posição do puxador central.
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
  double _sliderPosition = 0.5;

  @override
  Widget build(BuildContext context) {
    final color = widget.dividerColor ?? Colors.white;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width <= 0) return const SizedBox.shrink();

        final clipWidth = width * _sliderPosition;
        final handleLeft = (clipWidth - 20).clamp(0.0, width - 40).toDouble();

        return SizedBox(
          width: width,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _ComparisonImage(
                url: widget.afterImage,
                width: width,
                height: widget.height,
                borderRadius: BorderRadius.circular(12),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: clipWidth,
                child: ClipRect(
                  child: _ComparisonImage(
                    url: widget.beforeImage,
                    width: width,
                    height: widget.height,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: clipWidth - 1.5,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: color),
              ),
              // A área de gesto ocupa sempre o mesmo espaço. Apenas o
              // divisor visual se move; isto evita referências de hit-test
              // inválidas no Flutter Web durante o arrasto.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      _sliderPosition =
                          (_sliderPosition + details.delta.dx / width).clamp(
                            0.0,
                            1.0,
                          );
                    });
                  },
                ),
              ),
              Positioned(
                left: handleLeft,
                top: widget.height / 2 - 21,
                child: IgnorePointer(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.34),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.compare_arrows_rounded,
                      size: 22,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ComparisonImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const _ComparisonImage({
    required this.url,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          url,
          width: width,
          height: height,
          color: Colors.black.withValues(alpha: 0.08),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Container(
            color: Colors.grey[900],
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 44,
            ),
          ),
        ),
      ),
    );
  }
}
