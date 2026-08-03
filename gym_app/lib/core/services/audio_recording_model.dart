import 'dart:typed_data';

class RecordedAudio {
  final Uint8List bytes;
  final String extension;
  final String contentType;
  final int? durationMs;

  const RecordedAudio({
    required this.bytes,
    required this.extension,
    required this.contentType,
    this.durationMs,
  });
}
