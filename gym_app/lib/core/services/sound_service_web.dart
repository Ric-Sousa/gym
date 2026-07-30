import 'dart:html' as html;
import '../config/notification_sounds.dart';

/// Web implementation of sound service.
///
/// Uses an HTML Audio element to play the configured notification sound.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  html.AudioElement? _audio;
  String _currentAsset = defaultSoundAsset;

  /// Define o ficheiro de som a usar nas notificações.
  void setSound(String assetPath) {
    _currentAsset = assetPath;
    // Força recriação do elemento com o novo source
    _audio = null;
  }

  void playNotificationChime() {
    _play(_currentAsset);
  }

  void playErrorSound() {
    _play(errorSoundAsset);
  }

  void _play(String asset) {
    try {
      _audio = html.AudioElement(asset)
        ..load();
      _audio!
        ..currentTime = 0
        ..play();
    } catch (_) {
      // Som é extra — falha silenciosa.
    }
  }
}
