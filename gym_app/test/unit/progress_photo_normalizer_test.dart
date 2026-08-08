import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/core/utils/progress_photo_normalizer.dart';

void main() {
  test('normaliza uma imagem horizontal para 1024x1280', () async {
    final sourceBytes = await _createPng(width: 1600, height: 900);

    final normalized = await normalizeProgressPhoto(sourceBytes);
    final codec = await ui.instantiateImageCodec(normalized);
    try {
      final frame = await codec.getNextFrame();
      expect(frame.image.width, progressPhotoWidth);
      expect(frame.image.height, progressPhotoHeight);
      frame.image.dispose();
    } finally {
      codec.dispose();
    }
  });

  test('rejeita bytes vazios', () {
    expect(
      normalizeProgressPhoto(Uint8List(0)),
      throwsA(isA<FormatException>()),
    );
  });
}

Future<Uint8List> _createPng({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF336699),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}
