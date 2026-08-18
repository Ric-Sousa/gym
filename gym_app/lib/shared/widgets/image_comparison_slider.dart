import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/utils/storage_resource.dart';

/// Comparador visual de progresso antes/depois.
///
/// As duas imagens ocupam a mesma área e permanecem fixas. A imagem "Antes"
/// é apenas recortada à esquerda do divisor, permitindo comparar as fotos em
/// tempo real durante o arrasto.
class ImageComparisonSlider extends StatefulWidget {
  final String beforeImage;
  final String afterImage;
  final double width;
  final double height;
  final Color? dividerColor;

  /// Ajusta o enquadramento das fotos sem alterar a área do comparador.
  final BoxFit imageFit;

  /// Remove o padding lateral interno para a imagem ocupar todo o quadro.
  final bool edgeToEdge;

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
    required this.width,
    this.height = 300,
    this.dividerColor,
    this.imageFit = BoxFit.cover,
    this.edgeToEdge = false,
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

  Widget _image({
    required String url,
    required Color fallbackColor,
    BoxFit? fit,
  }) {
    return StorageImage(
      url,
      fit: fit ?? widget.imageFit,
      width: double.infinity,
      height: double.infinity,
      placeholder: Container(
        color: fallbackColor,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      ),
      error: Container(
        color: fallbackColor,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, color: Colors.white54, size: 44),
            SizedBox(height: 8),
            Text(
              'Imagem indisponível',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
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
    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label.isNotEmpty)
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
              const SizedBox(height: 3),
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

  Widget _comparisonImage({required String url, required Color fallbackColor}) {
    return _image(url: url, fallbackColor: fallbackColor);
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
    final width = widget.width.clamp(1.0, double.infinity).toDouble();
    final horizontalPadding = widget.edgeToEdge ? 0.0 : _cardTopPadding;
    final contentWidth =
        (width - (_cardBorderWidth * 2) - (horizontalPadding * 2))
            .clamp(1.0, double.infinity)
            .toDouble();
    final totalHeight = widget.height.clamp(120.0, double.infinity).toDouble();
    final imageHeight = hasFooter
        ? (totalHeight -
                  (_cardBorderWidth * 2) -
                  _cardTopPadding -
                  _footerHeight)
              .clamp(64.0, double.infinity)
              .toDouble()
        : (totalHeight - (_cardBorderWidth * 2) - _cardTopPadding)
              .clamp(64.0, double.infinity)
              .toDouble();
    final canKeepHandleInside = contentWidth >= _handleSize;
    final minPosition = canKeepHandleInside
        ? (_handleSize / 2) / contentWidth
        : 0.5;
    final maxPosition = canKeepHandleInside ? 1 - minPosition : 0.5;
    final effectivePosition = _sliderPosition
        .clamp(minPosition, maxPosition)
        .toDouble();
    final dividerX = contentWidth * effectivePosition;
    final handleLeft = dividerX - (_handleSize / 2);
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
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            _cardTopPadding,
            horizontalPadding,
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
                width: contentWidth,
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
                              _comparisonImage(
                                url: widget.afterImage,
                                fallbackColor: Colors.grey.shade900,
                              ),
                              ClipRect(
                                clipper: _BeforeImageClipper(effectivePosition),
                                child: _comparisonImage(
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
                          top: imageHeight / 2 - (_handleSize / 2),
                          child: IgnorePointer(
                            child: _buildHandle(dividerColor),
                          ),
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
