import 'package:just_audio/just_audio.dart';

/// Mobile (Android/iOS/Desktop) implementation using just_audio.
///
/// Plays the configured notification sound asset.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  AudioPlayer? _player;
  String _currentAsset = 'assets/sounds/chime.wav';

  /// Define o ficheiro de som a usar nas notificações.
  void setSound(String assetPath) {
    _currentAsset = assetPath;
  }

  void playNotificationChime() {
    try {
      _player ??= AudioPlayer();
      _player!.setAsset(_currentAsset);
      _player!.play();
    } catch (_) {
      // Som é extra — falha silenciosa.
    }
  }
}
