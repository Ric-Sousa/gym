import 'dart:typed_data';
import 'dart:ui' as ui;

/// Dimensões padrão usadas pelo comparador de progresso.
const progressPhotoWidth = 1024;
const progressPhotoHeight = 1280;

/// Converte uma imagem arbitrária para o formato 4:5 do comparador.
///
/// A imagem é convertida para um canvas 4:5, sem deformação e sem filtros
/// artificiais. O enquadramento final usa a mesma proporção no comparador,
/// permitindo que a fotografia ocupe toda a largura disponível.
/// O resultado é um PNG para manter a mesma implementação em Web e mobile.
Future<Uint8List> normalizeProgressPhoto(Uint8List bytes) async {
  if (bytes.isEmpty) {
    throw const FormatException('A fotografia está vazia.');
  }

  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    final source = frame.image;
    ui.Picture? picture;

    try {
      final targetRect = ui.Rect.fromLTWH(
        0,
        0,
        progressPhotoWidth.toDouble(),
        progressPhotoHeight.toDouble(),
      );
      final sourceRect = ui.Rect.fromLTWH(
        0,
        0,
        source.width.toDouble(),
        source.height.toDouble(),
      );
      // Usa o mesmo princípio de BoxFit.cover do comparador: a imagem ocupa
      // todo o canvas, sem esticar e sem criar barras laterais desfocadas.
      // Como o canvas é 4:5 e a fotografia pode ter outra proporção, algum
      // recorte proporcional é inevitável para preencher os dois eixos.
      final scale = _coverScale(
        sourceWidth: source.width,
        sourceHeight: source.height,
        targetWidth: progressPhotoWidth,
        targetHeight: progressPhotoHeight,
      );
      final scaledWidth = source.width * scale;
      final scaledHeight = source.height * scale;
      final destinationRect = ui.Rect.fromLTWH(
        (progressPhotoWidth - scaledWidth) / 2,
        (progressPhotoHeight - scaledHeight) / 2,
        scaledWidth,
        scaledHeight,
      );

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.save();
      canvas.clipRect(targetRect);
      canvas.drawImageRect(
        source,
        sourceRect,
        destinationRect,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();

      picture = recorder.endRecording();
      final normalized = await picture.toImage(
        progressPhotoWidth,
        progressPhotoHeight,
      );
      try {
        final data = await normalized.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (data == null) {
          throw const FormatException(
            'Não foi possível converter a fotografia.',
          );
        }
        return data.buffer.asUint8List();
      } finally {
        normalized.dispose();
      }
    } finally {
      picture?.dispose();
      source.dispose();
    }
  } finally {
    codec.dispose();
  }
}

double _coverScale({
  required int sourceWidth,
  required int sourceHeight,
  required int targetWidth,
  required int targetHeight,
}) {
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    throw const FormatException('Dimensões de fotografia inválidas.');
  }

  final widthScale = targetWidth / sourceWidth;
  final heightScale = targetHeight / sourceHeight;
  return widthScale > heightScale ? widthScale : heightScale;
}
