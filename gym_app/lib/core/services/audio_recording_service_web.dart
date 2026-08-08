import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;

import 'package:http/http.dart' as http;
import 'package:record/record.dart';

import 'audio_recording_model.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Permissão do microfone não concedida.');
    }

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.opus,
        bitRate: 96000,
        sampleRate: 48000,
      ),
      path: '',
    );
  }

  Future<RecordedAudio?> stop() async {
    final blobUrl = await _recorder.stop();
    if (blobUrl == null || blobUrl.isEmpty) return null;

    try {
      final response = await http.get(Uri.parse(blobUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return RecordedAudio(
        bytes: Uint8List.fromList(response.bodyBytes),
        extension: _extensionForMime(response.headers['content-type']),
        contentType: response.headers['content-type'] ?? 'audio/webm',
      );
    } finally {
      html.Url.revokeObjectUrl(blobUrl);
    }
  }

  String _extensionForMime(String? mime) {
    if (mime?.contains('ogg') == true) return 'ogg';
    if (mime?.contains('mp4') == true || mime?.contains('m4a') == true) {
      return 'm4a';
    }
    return 'webm';
  }

  Future<void> cancel() async {
    final blobUrl = await _recorder.stop();
    if (blobUrl != null && blobUrl.isNotEmpty) {
      html.Url.revokeObjectUrl(blobUrl);
    }
  }

  Future<void> dispose() => _recorder.dispose();
}
