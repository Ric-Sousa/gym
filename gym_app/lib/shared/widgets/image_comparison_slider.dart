import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Comparador visual de progresso antes/depois.
///
/// As imagens ocupam a mesma área e a imagem "Antes" é apenas recortada à
/// esquerda do divisor. Assim, o arrasto não altera as proporções das fotos.
/// O cartão e os metadados são opcionais para manter a API compatível com os
/// usos mais simples do widget.
class ImageComparisonSlider extends StatefulWidget {
  final String beforeImage;
  final String afterImage;
  final double height;
  final Color? dividerColor;

  /// Textos apresentados nos chips sobre as imagens.
  final String beforeLabel;
  final String afterLabel;
  final String? beforeDate;
  final String? afterDate;
  final String? beforeDetail;
  final String? afterDetail;

  /// Texto apresentado no rodapé do cartão. Use `null` para o ocultar.
  final String? instructionText;
  final bool alwaysShowLabels;
  final Color? cardColor;
  final Color handleColor;

  const ImageComparisonSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
    this.height = 300,
    this.dividerColor,
    this.beforeLabel = 'Antes',
    this.afterLabel = 'Depois',
    this.beforeDate,
    this.afterDate,
    this.beforeDetail,
    this.afterDetail,
    this.instructionText = 'Arraste para comparar',
    this.alwaysShowLabels = true,
    this.cardColor,
    this.handleColor = Colors.white,
  });

  @override
  State<ImageComparisonSlider> createState() => _ImageComparisonSliderState();
}

class _ImageComparisonSliderState extends State<ImageComparisonSlider> {
  static const _cardRadius = 22.0;
  static const _imageRadius = 17.0;
  static const _handleSize = 48.0;
  static const _dividerWidth = 2.0;
  static const _footerHeight = 40.0;
  static const _cardTopPadding = 10.0;
  static const _cardBorderWidth = 1.0;

  double _sliderPosition = 0.5;
  bool _isDragging = false;

  void _startDragging(DragStartDetails _) {
    if (!_isDragging) setState(() => _isDragging = true);
  }

  void _updatePosition(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    setState(() {
      _sliderPosition = (_sliderPosition + details.delta.dx / width)
          .clamp(0.0, 1.0)
          .toDouble();
    });
  }

  void _stopDragging(DragEndDetails _) {
    if (_isDragging) setState(() => _isDragging = false);
  }

  void _moveBy(double amount) {
    setState(() {
      _sliderPosition = (_sliderPosition + amount).clamp(0.0, 1.0).toDouble();
    });
  }

  Widget _image({required String url, required Color fallbackColor}) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, _, _) => Container(
        color: fallbackColor,
        alignment: Alignment.center,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }

  Widget _metadataChip({
    required String label,
    required String? date,
    required String? detail,
    required Alignment alignment,
    required Color accent,
    required double maxWidth,
  }) {
    final hasExtra = date != null || detail != null;
    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (date != null) ...[
              const SizedBox(height: 2),
              Text(
                date,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (detail != null) ...[
              SizedBox(height: hasExtra ? 3 : 0),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHandle(Color dividerColor) {
    return Container(
      width: _handleSize,
      height: _handleSize,
      decoration: BoxDecoration(
        color: widget.handleColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.compare_arrows_rounded,
        size: 28,
        color: dividerColor == Colors.white ? Colors.black87 : dividerColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dividerColor = widget.dividerColor ?? Colors.white;
    final cardColor = widget.cardColor ?? const Color(0xFF202020);
    final hasFooter = widget.instructionText != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // O cartão tem 10 px de padding lateral; o divisor é calculado na
        // largura real da área da fotografia para continuar geometricamente
        // centrado no cartão.
        final contentWidth =
            (width - (_cardBorderWidth * 2) - (_cardTopPadding * 2))
                .clamp(0.0, double.infinity)
                .toDouble();
        final totalHeight = widget.height.clamp(120.0, double.infinity).toDouble();
        final imageHeight = hasFooter
            ? (totalHeight -
                      (_cardBorderWidth * 2) -
                      _cardTopPadding -
                      _footerHeight)
                .clamp(64.0, double.infinity)
                .toDouble()
            : (totalHeight -
                      (_cardBorderWidth * 2) -
                      _cardTopPadding)
                .clamp(64.0, double.infinity)
                .toDouble();
        const handleRadius = _handleSize / 2;
        final usableWidth = contentWidth.isFinite && contentWidth > 0;
        final canKeepHandleInside = usableWidth && contentWidth >= _handleSize;
        final minPosition = canKeepHandleInside
            ? handleRadius / contentWidth
            : 0.5;
        final maxPosition = canKeepHandleInside ? 1 - minPosition : 0.5;
        final effectivePosition = usableWidth
            ? _sliderPosition.clamp(minPosition, maxPosition).toDouble()
            : 0.5;
        final dividerX = usableWidth ? contentWidth * effectivePosition : 0.0;
        final handleLeft = usableWidth ? dividerX - handleRadius : 0.0;
        final labelsVisible = widget.alwaysShowLabels || _isDragging;
        final chipMaxWidth = ((contentWidth - 40) / 2)
            .clamp(64.0, 145.0)
            .toDouble();

        return SizedBox(
          width: width,
          height: totalHeight,
          child: Semantics(
            container: true,
            slider: true,
            label: 'Comparação de imagens antes e depois',
            value: '${(_sliderPosition * 100).round()}% ${widget.beforeLabel}',
            increasedValue: 'Mais imagem ${widget.beforeLabel}',
            decreasedValue: 'Mais imagem ${widget.afterLabel}',
            onIncrease: () => _moveBy(0.05),
            onDecrease: () => _moveBy(-0.05),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                _cardTopPadding,
                _cardTopPadding,
                _cardTopPadding,
                0,
              ),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(_cardRadius),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeLeftRight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        dragStartBehavior: DragStartBehavior.start,
                        onHorizontalDragStart: _startDragging,
                        onHorizontalDragUpdate: (details) =>
                            _updatePosition(details, contentWidth),
                        onHorizontalDragEnd: _stopDragging,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(_imageRadius),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _image(
                                    url: widget.afterImage,
                                    fallbackColor: Colors.grey.shade900,
                                  ),
                                  ClipRect(
                                    clipper: _BeforeImageClipper(effectivePosition),
                                    child: _image(
                                      url: widget.beforeImage,
                                      fallbackColor: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            AnimatedOpacity(
                              opacity: labelsVisible ? 1 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _metadataChip(
                                      label: widget.beforeLabel,
                                      date: widget.beforeDate,
                                      detail: widget.beforeDetail,
                                      alignment: Alignment.topLeft,
                                      accent: dividerColor,
                                      maxWidth: chipMaxWidth,
                                    ),
                                    _metadataChip(
                                      label: widget.afterLabel,
                                      date: widget.afterDate,
                                      detail: widget.afterDetail,
                                      alignment: Alignment.topRight,
                                      accent: dividerColor,
                                      maxWidth: chipMaxWidth,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              key: const ValueKey('image-comparison-divider'),
                              left: dividerX - _dividerWidth / 2,
                              top: 0,
                              bottom: 0,
                              child: IgnorePointer(
                                child: Container(
                                  width: _dividerWidth,
                                  color: dividerColor,
                                  foregroundDecoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.25),
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              key: const ValueKey('image-comparison-handle'),
                              left: handleLeft,
                              top: imageHeight / 2 - handleRadius,
                              child: IgnorePointer(child: _buildHandle(dividerColor)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (hasFooter)
                    SizedBox(
                      height: _footerHeight,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.swipe_rounded,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.48),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              widget.instructionText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.48),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BeforeImageClipper extends CustomClipper<Rect> {
  final double position;

  const _BeforeImageClipper(this.position);

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        0,
        0,
        size.width * position.clamp(0.0, 1.0).toDouble(),
        size.height,
      );

  @override
  bool shouldReclip(_BeforeImageClipper oldClipper) =>
      oldClipper.position != position;
}
