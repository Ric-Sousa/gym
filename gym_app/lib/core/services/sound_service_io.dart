import 'package:just_audio/just_audio.dart';
import '../config/notification_sounds.dart';

/// Mobile (Android/iOS/Desktop) implementation using just_audio.
///
/// Plays the configured notification sound asset.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  AudioPlayer? _player;
  String _currentAsset = defaultSoundAsset;

  /// Define o ficheiro de som a usar nas notificações.
  void setSound(String assetPath) {
    _currentAsset = assetPath;
  }

  void playNotificationChime() {
    _play(_currentAsset);
  }

  void playErrorSound() {
    _play(errorSoundAsset);
  }

  void _play(String asset) {
    try {
      _player ??= AudioPlayer();
      _player!.setAsset(asset);
      _player!.play();
    } catch (_) {
      // Som é extra — falha silenciosa.
    }
  }
}
