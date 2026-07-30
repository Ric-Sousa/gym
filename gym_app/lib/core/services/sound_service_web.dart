import 'dart:html' as html;

/// Web implementation of sound service.
///
/// Uses an HTML Audio element to play the configured notification sound.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  html.AudioElement? _audio;
  String _currentAsset = 'assets/sounds/chime.wav';

  /// Define o ficheiro de som a usar nas notificações.
  void setSound(String assetPath) {
    _currentAsset = assetPath;
    // Força recriação do elemento com o novo source
    _audio = null;
  }

  void playNotificationChime() {
    try {
      _audio ??= html.AudioElement(_currentAsset)
        ..load();
      _audio!
        ..currentTime = 0
        ..play();
    } catch (_) {
      // Som é extra — falha silenciosa.
    }
  }
}
