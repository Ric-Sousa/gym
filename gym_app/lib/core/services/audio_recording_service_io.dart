import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'audio_recording_model.dart';

class AudioRecordingService {
  final AudioRecorder _recorder = AudioRecorder();
  String? _path;

  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Permissão do microfone não concedida.');
    }

    final directory = await getTemporaryDirectory();
    _path =
        '${directory.path}/chat_${DateTime.now().microsecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 96000,
        sampleRate: 44100,
      ),
      path: _path!,
    );
  }

  Future<RecordedAudio?> stop() async {
    final path = await _recorder.stop();
    _path = null;
    if (path == null || path.isEmpty) return null;

    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    return RecordedAudio(
      bytes: Uint8List.fromList(bytes),
      extension: 'm4a',
      contentType: 'audio/mp4',
    );
  }

  Future<void> dispose() => _recorder.dispose();
}
