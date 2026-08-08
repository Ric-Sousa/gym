import 'package:just_audio/just_audio.dart';
import '../config/notification_sounds.dart';

/// Implementação mobile/desktop usando just_audio.
class SoundService {
  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  String _currentAsset = defaultSoundAsset;

  /// Mantém a API igual à implementação Web.
  void prepare() {}

  /// No nativo não existe bloqueio de autoplay; mantém a API idêntica ao Web.
  void unlock() {}

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
    () async {
      final player = AudioPlayer();
      try {
        await player.setAsset(asset);
        await player.play();
      } catch (_) {
        // Som é extra — falha silenciosa.
      } finally {
        try {
          await player.dispose();
        } catch (_) {}
      }
    }();
  }
}
