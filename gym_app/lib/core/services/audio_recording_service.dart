import 'audio_recording_model.dart';

import 'audio_recording_service_io.dart'
    if (dart.library.html) 'audio_recording_service_web.dart'
    as impl;

class AudioRecordingService {
  final impl.AudioRecordingService _implementation =
      impl.AudioRecordingService();

  Future<void> start() => _implementation.start();

  Future<RecordedAudio?> stop() => _implementation.stop();

  Future<void> dispose() => _implementation.dispose();
}
